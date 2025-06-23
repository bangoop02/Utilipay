;; title: Utilipay
;; version: 1.0.0
;; summary: Smart utility billing system for water and electricity payments
;; description: Decentralized utility billing platform that allows users to pay water and electricity bills using oracles for consumption data

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_BILL_NOT_FOUND (err u103))
(define-constant ERR_BILL_ALREADY_PAID (err u104))
(define-constant ERR_ORACLE_NOT_AUTHORIZED (err u105))
(define-constant ERR_INVALID_UTILITY_TYPE (err u106))
(define-constant ERR_CUSTOMER_NOT_REGISTERED (err u107))
(define-constant ERR_CUSTOMER_ALREADY_REGISTERED (err u108))

(define-constant UTILITY_WATER u1)
(define-constant UTILITY_ELECTRICITY u2)

(define-data-var next-bill-id uint u1)
(define-data-var water-rate uint u50)
(define-data-var electricity-rate uint u75)

(define-map customers
  { customer: principal }
  {
    name: (string-ascii 50),
    registered-at: uint,
    total-bills-paid: uint,
    total-amount-paid: uint
  }
)

(define-map bills
  { bill-id: uint }
  {
    customer: principal,
    utility-type: uint,
    consumption: uint,
    amount: uint,
    due-date: uint,
    paid: bool,
    paid-at: (optional uint),
    created-at: uint
  }
)

(define-map authorized-oracles
  { oracle: principal }
  { authorized: bool }
)

(define-map customer-balances
  { customer: principal }
  { balance: uint }
)

(define-map utility-providers
  { provider: principal }
  {
    name: (string-ascii 50),
    utility-type: uint,
    active: bool
  }
)

(define-public (register-customer (name (string-ascii 50)))
  (let ((customer tx-sender))
    (asserts! (is-none (map-get? customers { customer: customer })) ERR_CUSTOMER_ALREADY_REGISTERED)
    (map-set customers
      { customer: customer }
      {
        name: name,
        registered-at: stacks-block-height,
        total-bills-paid: u0,
        total-amount-paid: u0
      }
    )
    (map-set customer-balances { customer: customer } { balance: u0 })
    (ok true)
  )
)

(define-public (add-balance (amount uint))
  (let ((customer tx-sender))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-some (map-get? customers { customer: customer })) ERR_CUSTOMER_NOT_REGISTERED)
    (let ((current-balance (default-to u0 (get balance (map-get? customer-balances { customer: customer })))))
      (map-set customer-balances
        { customer: customer }
        { balance: (+ current-balance amount) }
      )
      (ok amount)
    )
  )
)

(define-public (authorize-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-oracles { oracle: oracle } { authorized: true })
    (ok true)
  )
)

(define-public (revoke-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-oracles { oracle: oracle } { authorized: false })
    (ok true)
  )
)

(define-public (register-utility-provider (name (string-ascii 50)) (utility-type uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (or (is-eq utility-type UTILITY_WATER) (is-eq utility-type UTILITY_ELECTRICITY)) ERR_INVALID_UTILITY_TYPE)
    (map-set utility-providers
      { provider: tx-sender }
      {
        name: name,
        utility-type: utility-type,
        active: true
      }
    )
    (ok true)
  )
)

(define-public (create-bill (customer principal) (utility-type uint) (consumption uint) (due-date uint))
  (let ((oracle tx-sender)
        (bill-id (var-get next-bill-id))
        (rate (if (is-eq utility-type UTILITY_WATER) (var-get water-rate) (var-get electricity-rate)))
        (amount (* consumption rate)))
    (asserts! (default-to false (get authorized (map-get? authorized-oracles { oracle: oracle }))) ERR_ORACLE_NOT_AUTHORIZED)
    (asserts! (is-some (map-get? customers { customer: customer })) ERR_CUSTOMER_NOT_REGISTERED)
    (asserts! (or (is-eq utility-type UTILITY_WATER) (is-eq utility-type UTILITY_ELECTRICITY)) ERR_INVALID_UTILITY_TYPE)
    (asserts! (> consumption u0) ERR_INVALID_AMOUNT)
    (map-set bills
      { bill-id: bill-id }
      {
        customer: customer,
        utility-type: utility-type,
        consumption: consumption,
        amount: amount,
        due-date: due-date,
        paid: false,
        paid-at: none,
        created-at: stacks-block-height
      }
    )
    (var-set next-bill-id (+ bill-id u1))
    (ok bill-id)
  )
)

(define-public (pay-bill (bill-id uint))
  (let ((customer tx-sender)
        (bill (unwrap! (map-get? bills { bill-id: bill-id }) ERR_BILL_NOT_FOUND)))
    (asserts! (is-eq customer (get customer bill)) ERR_UNAUTHORIZED)
    (asserts! (not (get paid bill)) ERR_BILL_ALREADY_PAID)
    (let ((amount (get amount bill))
          (current-balance (default-to u0 (get balance (map-get? customer-balances { customer: customer })))))
      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
      (map-set customer-balances
        { customer: customer }
        { balance: (- current-balance amount) }
      )
      (map-set bills
        { bill-id: bill-id }
        (merge bill { paid: true, paid-at: (some stacks-block-height) })
      )
      (let ((customer-data (unwrap! (map-get? customers { customer: customer }) ERR_CUSTOMER_NOT_REGISTERED)))
        (map-set customers
          { customer: customer }
          (merge customer-data {
            total-bills-paid: (+ (get total-bills-paid customer-data) u1),
            total-amount-paid: (+ (get total-amount-paid customer-data) amount)
          })
        )
      )
      (ok amount)
    )
  )
)

(define-public (update-water-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-rate u0) ERR_INVALID_AMOUNT)
    (var-set water-rate new-rate)
    (ok new-rate)
  )
)

(define-public (update-electricity-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-rate u0) ERR_INVALID_AMOUNT)
    (var-set electricity-rate new-rate)
    (ok new-rate)
  )
)

(define-read-only (get-customer (customer principal))
  (map-get? customers { customer: customer })
)

(define-read-only (get-customer-balance (customer principal))
  (default-to u0 (get balance (map-get? customer-balances { customer: customer })))
)

(define-read-only (get-bill (bill-id uint))
  (map-get? bills { bill-id: bill-id })
)

(define-read-only (is-oracle-authorized (oracle principal))
  (default-to false (get authorized (map-get? authorized-oracles { oracle: oracle })))
)

(define-read-only (get-water-rate)
  (var-get water-rate)
)

(define-read-only (get-electricity-rate)
  (var-get electricity-rate)
)

(define-read-only (get-next-bill-id)
  (var-get next-bill-id)
)

(define-read-only (get-utility-provider (provider principal))
  (map-get? utility-providers { provider: provider })
)

(define-read-only (calculate-bill-amount (utility-type uint) (consumption uint))
  (let ((rate (if (is-eq utility-type UTILITY_WATER) (var-get water-rate) (var-get electricity-rate))))
    (* consumption rate)
  )
)

(define-read-only (is-bill-overdue (bill-id uint))
  (match (map-get? bills { bill-id: bill-id })
    bill (and (not (get paid bill)) (> stacks-block-height (get due-date bill)))
    false
  )
)

(define-read-only (get-customer-unpaid-bills-count (customer principal))
  (let ((total-bills u0))
    total-bills
  )
)