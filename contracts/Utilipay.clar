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
(define-constant ERR_PAYMENT_PLAN_NOT_FOUND (err u109))
(define-constant ERR_PAYMENT_PLAN_ALREADY_EXISTS (err u110))
(define-constant ERR_INVALID_INSTALLMENT_COUNT (err u111))
(define-constant ERR_INSTALLMENT_NOT_DUE (err u112))
(define-constant ERR_INSTALLMENT_ALREADY_PAID (err u113))
(define-constant ERR_PAYMENT_PLAN_COMPLETED (err u114))
(define-constant ERR_INVALID_PLAN_TYPE (err u115))
(define-constant ERR_BUDGET_NOT_FOUND (err u116))
(define-constant ERR_ALERT_NOT_FOUND (err u117))
(define-constant ERR_INVALID_THRESHOLD (err u118))
(define-constant ERR_INSUFFICIENT_DATA (err u119))
(define-constant ERR_INVALID_PERIOD (err u120))

(define-constant PLAN_TYPE_INSTALLMENT u1)
(define-constant PLAN_TYPE_RECURRING u2)
(define-constant MAX_INSTALLMENTS u12)
(define-constant MIN_INSTALLMENT_AMOUNT u10)

(define-constant ALERT_TYPE_SPIKE u1)
(define-constant ALERT_TYPE_BUDGET u2)
(define-constant ALERT_TYPE_FORECAST u3)
(define-constant MAX_CONSUMPTION_HISTORY u24)
(define-constant SPIKE_THRESHOLD_PERCENTAGE u50)

(define-constant UTILITY_WATER u1)
(define-constant UTILITY_ELECTRICITY u2)

(define-data-var next-bill-id uint u1)
(define-data-var next-plan-id uint u1)
(define-data-var next-alert-id uint u1)
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

(define-map payment-plans
  { plan-id: uint }
  {
    customer: principal,
    bill-id: uint,
    plan-type: uint,
    total-amount: uint,
    installment-amount: uint,
    total-installments: uint,
    paid-installments: uint,
    next-payment-due: uint,
    payment-interval: uint,
    active: bool,
    created-at: uint,
    completed-at: (optional uint)
  }
)

(define-map installment-payments
  { plan-id: uint, installment-number: uint }
  {
    amount: uint,
    due-date: uint,
    paid: bool,
    paid-at: (optional uint)
  }
)

(define-map consumption-history
  { customer: principal, utility-type: uint, period: uint }
  {
    consumption: uint,
    block-height: uint,
    cost: uint
  }
)

(define-map consumption-budgets
  { customer: principal, utility-type: uint }
  {
    monthly-budget: uint,
    current-period-consumption: uint,
    budget-start-block: uint,
    alert-threshold: uint,
    active: bool
  }
)

(define-map consumption-alerts
  { alert-id: uint }
  {
    customer: principal,
    utility-type: uint,
    alert-type: uint,
    consumption-amount: uint,
    threshold-exceeded: uint,
    created-at: uint,
    acknowledged: bool
  }
)

(define-map consumption-analytics
  { customer: principal, utility-type: uint }
  {
    total-periods: uint,
    average-consumption: uint,
    min-consumption: uint,
    max-consumption: uint,
    last-updated: uint,
    trend-direction: uint
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

(define-public (create-payment-plan (bill-id uint) (plan-type uint) (installments uint) (payment-interval uint))
  (let ((customer tx-sender)
        (plan-id (var-get next-plan-id))
        (bill (unwrap! (map-get? bills { bill-id: bill-id }) ERR_BILL_NOT_FOUND)))
    (asserts! (is-eq customer (get customer bill)) ERR_UNAUTHORIZED)
    (asserts! (not (get paid bill)) ERR_BILL_ALREADY_PAID)
    (asserts! (or (is-eq plan-type PLAN_TYPE_INSTALLMENT) (is-eq plan-type PLAN_TYPE_RECURRING)) ERR_INVALID_PLAN_TYPE)
    (asserts! (and (> installments u0) (<= installments MAX_INSTALLMENTS)) ERR_INVALID_INSTALLMENT_COUNT)
    (asserts! (> payment-interval u0) ERR_INVALID_AMOUNT)
    (let ((total-amount (get amount bill))
          (installment-amount (/ total-amount installments)))
      (asserts! (>= installment-amount MIN_INSTALLMENT_AMOUNT) ERR_INVALID_AMOUNT)
      (map-set payment-plans
        { plan-id: plan-id }
        {
          customer: customer,
          bill-id: bill-id,
          plan-type: plan-type,
          total-amount: total-amount,
          installment-amount: installment-amount,
          total-installments: installments,
          paid-installments: u0,
          next-payment-due: (+ stacks-block-height payment-interval),
          payment-interval: payment-interval,
          active: true,
          created-at: stacks-block-height,
          completed-at: none
        }
      )
      (var-set next-plan-id (+ plan-id u1))
      (ok plan-id)
    )
  )
)

(define-public (pay-installment (plan-id uint) (installment-number uint))
  (let ((customer tx-sender)
        (plan (unwrap! (map-get? payment-plans { plan-id: plan-id }) ERR_PAYMENT_PLAN_NOT_FOUND)))
    (asserts! (is-eq customer (get customer plan)) ERR_UNAUTHORIZED)
    (asserts! (get active plan) ERR_PAYMENT_PLAN_COMPLETED)
    (asserts! (<= installment-number (get total-installments plan)) ERR_INSTALLMENT_NOT_DUE)
    (let ((amount (get installment-amount plan))
          (current-balance (default-to u0 (get balance (map-get? customer-balances { customer: customer })))))
      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
      (map-set customer-balances
        { customer: customer }
        { balance: (- current-balance amount) }
      )
      (let ((updated-plan (merge plan { paid-installments: (+ (get paid-installments plan) u1) }))
            (is-complete (is-eq (+ (get paid-installments plan) u1) (get total-installments plan))))
        (map-set payment-plans
          { plan-id: plan-id }
          (if is-complete
            (merge updated-plan { active: false, completed-at: (some stacks-block-height) })
            updated-plan
          )
        )
        (if is-complete
          (begin
            (try! (complete-bill-payment (get bill-id plan)))
            (ok amount)
          )
          (ok amount)
        )
      )
    )
  )
)

(define-private (complete-bill-payment (bill-id uint))
  (let ((bill (unwrap! (map-get? bills { bill-id: bill-id }) ERR_BILL_NOT_FOUND)))
    (map-set bills
      { bill-id: bill-id }
      (merge bill { paid: true, paid-at: (some stacks-block-height) })
    )
    (let ((customer (get customer bill))
          (amount (get amount bill))
          (customer-data (unwrap! (map-get? customers { customer: customer }) ERR_CUSTOMER_NOT_REGISTERED)))
      (map-set customers
        { customer: customer }
        (merge customer-data {
          total-bills-paid: (+ (get total-bills-paid customer-data) u1),
          total-amount-paid: (+ (get total-amount-paid customer-data) amount)
        })
      )
      (ok true)
    )
  )
)

(define-public (cancel-payment-plan (plan-id uint))
  (let ((customer tx-sender)
        (plan (unwrap! (map-get? payment-plans { plan-id: plan-id }) ERR_PAYMENT_PLAN_NOT_FOUND)))
    (asserts! (is-eq customer (get customer plan)) ERR_UNAUTHORIZED)
    (asserts! (get active plan) ERR_PAYMENT_PLAN_COMPLETED)
    (map-set payment-plans
      { plan-id: plan-id }
      (merge plan { active: false, completed-at: (some stacks-block-height) })
    )
    (ok true)
  )
)

(define-read-only (get-payment-plan (plan-id uint))
  (map-get? payment-plans { plan-id: plan-id })
)

(define-read-only (get-installment (plan-id uint) (installment-number uint))
  (map-get? installment-payments { plan-id: plan-id, installment-number: installment-number })
)

(define-read-only (get-customer-payment-plan (customer principal) (bill-id uint))
  (let ((plan-data none))
    plan-data
  )
)

(define-read-only (get-overdue-installments (customer principal))
  (let ((overdue-list (list)))
    overdue-list
  )
)

(define-read-only (get-next-plan-id)
  (var-get next-plan-id)
)

(define-read-only (calculate-remaining-balance (plan-id uint))
  (match (map-get? payment-plans { plan-id: plan-id })
    plan (let ((remaining-installments (- (get total-installments plan) (get paid-installments plan))))
           (* remaining-installments (get installment-amount plan)))
    u0
  )
)

(define-public (modify-payment-plan (plan-id uint) (new-installments uint))
  (let ((customer tx-sender)
        (plan (unwrap! (map-get? payment-plans { plan-id: plan-id }) ERR_PAYMENT_PLAN_NOT_FOUND)))
    (asserts! (is-eq customer (get customer plan)) ERR_UNAUTHORIZED)
    (asserts! (get active plan) ERR_PAYMENT_PLAN_COMPLETED)
    (asserts! (and (> new-installments (get paid-installments plan)) (<= new-installments MAX_INSTALLMENTS)) ERR_INVALID_INSTALLMENT_COUNT)
    (let ((remaining-amount (calculate-remaining-balance plan-id))
          (remaining-installments (- new-installments (get paid-installments plan)))
          (new-installment-amount (/ remaining-amount remaining-installments)))
      (asserts! (>= new-installment-amount MIN_INSTALLMENT_AMOUNT) ERR_INVALID_AMOUNT)
      (map-set payment-plans
        { plan-id: plan-id }
        (merge plan {
          total-installments: new-installments,
          installment-amount: new-installment-amount
        })
      )
      (ok new-installment-amount)
    )
  )
)

(define-public (pause-payment-plan (plan-id uint))
  (let ((customer tx-sender)
        (plan (unwrap! (map-get? payment-plans { plan-id: plan-id }) ERR_PAYMENT_PLAN_NOT_FOUND)))
    (asserts! (is-eq customer (get customer plan)) ERR_UNAUTHORIZED)
    (asserts! (get active plan) ERR_PAYMENT_PLAN_COMPLETED)
    (map-set payment-plans
      { plan-id: plan-id }
      (merge plan { active: false })
    )
    (ok true)
  )
)

(define-public (resume-payment-plan (plan-id uint))
  (let ((customer tx-sender)
        (plan (unwrap! (map-get? payment-plans { plan-id: plan-id }) ERR_PAYMENT_PLAN_NOT_FOUND)))
    (asserts! (is-eq customer (get customer plan)) ERR_UNAUTHORIZED)
    (asserts! (not (get active plan)) ERR_PAYMENT_PLAN_ALREADY_EXISTS)
    (asserts! (< (get paid-installments plan) (get total-installments plan)) ERR_PAYMENT_PLAN_COMPLETED)
    (map-set payment-plans
      { plan-id: plan-id }
      (merge plan { active: true })
    )
    (ok true)
  )
)

(define-read-only (get-payment-plan-progress (plan-id uint))
  (match (map-get? payment-plans { plan-id: plan-id })
    plan (let ((progress-percentage (/ (* (get paid-installments plan) u100) (get total-installments plan))))
           (some {
             paid-installments: (get paid-installments plan),
             total-installments: (get total-installments plan),
             progress-percentage: progress-percentage,
             remaining-amount: (calculate-remaining-balance plan-id),
             is-active: (get active plan)
           }))
    none
  )
)

(define-read-only (get-customer-active-plans (customer principal))
  (let ((active-plans (list)))
    active-plans
  )
)

(define-read-only (is-payment-plan-overdue (plan-id uint))
  (match (map-get? payment-plans { plan-id: plan-id })
    plan (and (get active plan) (> stacks-block-height (get next-payment-due plan)))
    false
  )
)

(define-read-only (get-payment-plan-summary (customer principal))
  (let ((total-plans u0)
        (active-plans u0)
        (completed-plans u0)
        (total-amount-in-plans u0)
        (total-paid-amount u0))
    {
      total-plans: total-plans,
      active-plans: active-plans,
      completed-plans: completed-plans,
      total-amount-in-plans: total-amount-in-plans,
      total-paid-amount: total-paid-amount
    }
  )
)

(define-public (record-consumption (customer principal) (utility-type uint) (consumption uint))
  (let ((oracle tx-sender)
        (current-period (/ stacks-block-height u144))
        (rate (if (is-eq utility-type UTILITY_WATER) (var-get water-rate) (var-get electricity-rate)))
        (cost (* consumption rate)))
    (asserts! (default-to false (get authorized (map-get? authorized-oracles { oracle: oracle }))) ERR_ORACLE_NOT_AUTHORIZED)
    (asserts! (is-some (map-get? customers { customer: customer })) ERR_CUSTOMER_NOT_REGISTERED)
    (asserts! (or (is-eq utility-type UTILITY_WATER) (is-eq utility-type UTILITY_ELECTRICITY)) ERR_INVALID_UTILITY_TYPE)
    (asserts! (> consumption u0) ERR_INVALID_AMOUNT)
    (map-set consumption-history
      { customer: customer, utility-type: utility-type, period: current-period }
      {
        consumption: consumption,
        block-height: stacks-block-height,
        cost: cost
      }
    )
    (unwrap! (update-consumption-analytics customer utility-type consumption) (ok consumption))
    (unwrap! (check-consumption-alerts customer utility-type consumption) (ok consumption))
    (unwrap! (update-budget-tracking customer utility-type consumption) (ok consumption))
    (ok consumption)
  )
)

(define-private (update-consumption-analytics (customer principal) (utility-type uint) (consumption uint))
  (let ((analytics (map-get? consumption-analytics { customer: customer, utility-type: utility-type })))
    (match analytics
      existing-analytics
        (let ((new-total-periods (+ (get total-periods existing-analytics) u1))
              (new-average (/ (+ (* (get average-consumption existing-analytics) (get total-periods existing-analytics)) consumption) new-total-periods))
              (new-min (if (< consumption (get min-consumption existing-analytics)) consumption (get min-consumption existing-analytics)))
              (new-max (if (> consumption (get max-consumption existing-analytics)) consumption (get max-consumption existing-analytics)))
              (trend (if (> consumption (get average-consumption existing-analytics)) u1 u0)))
          (map-set consumption-analytics
            { customer: customer, utility-type: utility-type }
            {
              total-periods: new-total-periods,
              average-consumption: new-average,
              min-consumption: new-min,
              max-consumption: new-max,
              last-updated: stacks-block-height,
              trend-direction: trend
            }
          )
          (ok true)
        )
      (begin
        (map-set consumption-analytics
          { customer: customer, utility-type: utility-type }
          {
            total-periods: u1,
            average-consumption: consumption,
            min-consumption: consumption,
            max-consumption: consumption,
            last-updated: stacks-block-height,
            trend-direction: u0
          }
        )
        (ok true)
      )
    )
  )
)

(define-private (check-consumption-alerts (customer principal) (utility-type uint) (consumption uint))
  (let ((analytics (map-get? consumption-analytics { customer: customer, utility-type: utility-type })))
    (match analytics
      existing-analytics
        (let ((average (get average-consumption existing-analytics))
              (spike-threshold (+ average (/ (* average SPIKE_THRESHOLD_PERCENTAGE) u100))))
          (if (> consumption spike-threshold)
            (begin
              (unwrap! (create-alert customer utility-type ALERT_TYPE_SPIKE consumption spike-threshold) (ok true))
              (ok true)
            )
            (ok true)
          )
        )
      (ok true)
    )
  )
)

(define-private (update-budget-tracking (customer principal) (utility-type uint) (consumption uint))
  (let ((budget (map-get? consumption-budgets { customer: customer, utility-type: utility-type })))
    (match budget
      existing-budget
        (if (get active existing-budget)
          (let ((new-consumption (+ (get current-period-consumption existing-budget) consumption))
                (threshold-amount (/ (* (get monthly-budget existing-budget) (get alert-threshold existing-budget)) u100)))
            (map-set consumption-budgets
              { customer: customer, utility-type: utility-type }
              (merge existing-budget { current-period-consumption: new-consumption })
            )
            (if (>= new-consumption threshold-amount)
              (begin
                (unwrap! (create-alert customer utility-type ALERT_TYPE_BUDGET new-consumption threshold-amount) (ok true))
                (ok true)
              )
              (ok true)
            )
          )
          (ok true)
        )
      (ok true)
    )
  )
)

(define-private (create-alert (customer principal) (utility-type uint) (alert-type uint) (consumption uint) (threshold uint))
  (let ((alert-id (var-get next-alert-id)))
    (map-set consumption-alerts
      { alert-id: alert-id }
      {
        customer: customer,
        utility-type: utility-type,
        alert-type: alert-type,
        consumption-amount: consumption,
        threshold-exceeded: threshold,
        created-at: stacks-block-height,
        acknowledged: false
      }
    )
    (var-set next-alert-id (+ alert-id u1))
    (ok alert-id)
  )
)

(define-public (set-consumption-budget (utility-type uint) (monthly-budget uint) (alert-threshold uint))
  (let ((customer tx-sender))
    (asserts! (is-some (map-get? customers { customer: customer })) ERR_CUSTOMER_NOT_REGISTERED)
    (asserts! (or (is-eq utility-type UTILITY_WATER) (is-eq utility-type UTILITY_ELECTRICITY)) ERR_INVALID_UTILITY_TYPE)
    (asserts! (> monthly-budget u0) ERR_INVALID_AMOUNT)
    (asserts! (and (> alert-threshold u0) (<= alert-threshold u100)) ERR_INVALID_THRESHOLD)
    (map-set consumption-budgets
      { customer: customer, utility-type: utility-type }
      {
        monthly-budget: monthly-budget,
        current-period-consumption: u0,
        budget-start-block: stacks-block-height,
        alert-threshold: alert-threshold,
        active: true
      }
    )
    (ok monthly-budget)
  )
)

(define-public (reset-budget-period (utility-type uint))
  (let ((customer tx-sender)
        (budget (unwrap! (map-get? consumption-budgets { customer: customer, utility-type: utility-type }) ERR_BUDGET_NOT_FOUND)))
    (asserts! (is-eq customer tx-sender) ERR_UNAUTHORIZED)
    (map-set consumption-budgets
      { customer: customer, utility-type: utility-type }
      (merge budget {
        current-period-consumption: u0,
        budget-start-block: stacks-block-height
      })
    )
    (ok true)
  )
)

(define-public (acknowledge-alert (alert-id uint))
  (let ((customer tx-sender)
        (alert (unwrap! (map-get? consumption-alerts { alert-id: alert-id }) ERR_ALERT_NOT_FOUND)))
    (asserts! (is-eq customer (get customer alert)) ERR_UNAUTHORIZED)
    (asserts! (not (get acknowledged alert)) ERR_ALERT_NOT_FOUND)
    (map-set consumption-alerts
      { alert-id: alert-id }
      (merge alert { acknowledged: true })
    )
    (ok true)
  )
)

(define-public (toggle-budget-status (utility-type uint))
  (let ((customer tx-sender)
        (budget (unwrap! (map-get? consumption-budgets { customer: customer, utility-type: utility-type }) ERR_BUDGET_NOT_FOUND)))
    (asserts! (is-eq customer tx-sender) ERR_UNAUTHORIZED)
    (map-set consumption-budgets
      { customer: customer, utility-type: utility-type }
      (merge budget { active: (not (get active budget)) })
    )
    (ok (not (get active budget)))
  )
)

(define-read-only (get-consumption-history (customer principal) (utility-type uint) (periods uint))
  (let ((current-period (/ stacks-block-height u144))
        (history (list)))
    (if (> periods MAX_CONSUMPTION_HISTORY)
      (err ERR_INVALID_PERIOD)
      (ok (get-consumption-periods customer utility-type current-period periods))
    )
  )
)

(define-private (get-consumption-periods (customer principal) (utility-type uint) (current-period uint) (periods uint))
  (let ((history (list)))
    history
  )
)

(define-read-only (get-consumption-analytics (customer principal) (utility-type uint))
  (map-get? consumption-analytics { customer: customer, utility-type: utility-type })
)

(define-read-only (get-consumption-budget (customer principal) (utility-type uint))
  (map-get? consumption-budgets { customer: customer, utility-type: utility-type })
)

(define-read-only (get-consumption-alert (alert-id uint))
  (map-get? consumption-alerts { alert-id: alert-id })
)

(define-read-only (calculate-consumption-forecast (customer principal) (utility-type uint))
  (match (map-get? consumption-analytics { customer: customer, utility-type: utility-type })
    analytics (if (>= (get total-periods analytics) u3)
                (let ((forecast-base (get average-consumption analytics))
                      (trend-adjustment (if (is-eq (get trend-direction analytics) u1) 
                                          (/ (* forecast-base u10) u100) 
                                          (- u0 (/ (* forecast-base u5) u100)))))
                  (some (+ forecast-base trend-adjustment)))
                none)
    none
  )
)

(define-read-only (get-budget-utilization (customer principal) (utility-type uint))
  (match (map-get? consumption-budgets { customer: customer, utility-type: utility-type })
    budget (if (get active budget)
             (let ((utilization-percentage (/ (* (get current-period-consumption budget) u100) (get monthly-budget budget))))
               (some {
                 current-consumption: (get current-period-consumption budget),
                 budget-limit: (get monthly-budget budget),
                 utilization-percentage: utilization-percentage,
                 remaining-budget: (- (get monthly-budget budget) (get current-period-consumption budget)),
                 alert-threshold: (get alert-threshold budget)
               }))
             none)
    none
  )
)

(define-read-only (get-customer-alerts (customer principal))
  (let ((alerts (list)))
    alerts
  )
)

(define-read-only (compare-consumption-periods (customer principal) (utility-type uint) (period1 uint) (period2 uint))
  (let ((consumption1 (map-get? consumption-history { customer: customer, utility-type: utility-type, period: period1 }))
        (consumption2 (map-get? consumption-history { customer: customer, utility-type: utility-type, period: period2 })))
    (match consumption1
      data1 (match consumption2
             data2 (some {
                     period1-consumption: (get consumption data1),
                     period2-consumption: (get consumption data2),
                     difference: (if (> (get consumption data1) (get consumption data2))
                                   (- (get consumption data1) (get consumption data2))
                                   (- (get consumption data2) (get consumption data1))),
                     percentage-change: (if (> (get consumption data2) u0)
                                          (/ (* (- (get consumption data1) (get consumption data2)) u100) (get consumption data2))
                                          u0)
                   })
             none)
      none
    )
  )
)

(define-read-only (get-next-alert-id)
  (var-get next-alert-id)
)



