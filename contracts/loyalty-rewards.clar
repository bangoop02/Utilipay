;; Utility Loyalty Rewards Contract
;; Incentivizes customers for timely payments, energy conservation, and consistent usage

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_CUSTOMER_NOT_FOUND (err u201))
(define-constant ERR_INSUFFICIENT_POINTS (err u202))
(define-constant ERR_INVALID_AMOUNT (err u203))
(define-constant ERR_REWARD_NOT_FOUND (err u204))
(define-constant ERR_INVALID_TIER (err u205))
(define-constant ERR_REDEMPTION_FAILED (err u206))

;; Membership tiers
(define-constant TIER_BRONZE u1)
(define-constant TIER_SILVER u2)
(define-constant TIER_GOLD u3)
(define-constant TIER_PLATINUM u4)

;; Point earning rates
(define-constant POINTS_TIMELY_PAYMENT u10)
(define-constant POINTS_CONSERVATION u15)
(define-constant POINTS_CONSISTENCY u5)
(define-constant POINTS_REFERRAL u25)

;; Tier thresholds (points required)
(define-constant BRONZE_THRESHOLD u0)
(define-constant SILVER_THRESHOLD u100)
(define-constant GOLD_THRESHOLD u300)
(define-constant PLATINUM_THRESHOLD u600)

;; Reward types
(define-constant REWARD_BILL_DISCOUNT u1)
(define-constant REWARD_BALANCE_CREDIT u2)

(define-data-var next-reward-id uint u1)

;; Customer loyalty profiles
(define-map loyalty-profiles
  principal
  {
    total-points: uint,
    available-points: uint,
    tier: uint,
    consecutive-timely-payments: uint,
    conservation-achievements: uint,
    consistency-score: uint,
    joined-at: uint,
    last-activity: uint
  }
)

;; Available rewards catalog
(define-map reward-catalog
  uint
  {
    reward-type: uint,
    points-cost: uint,
    benefit-amount: uint,
    title: (string-ascii 30),
    description: (string-ascii 100),
    active: bool
  }
)

;; Customer reward redemptions history
(define-map redemption-history
  { customer: principal, redemption-id: uint }
  {
    reward-id: uint,
    points-spent: uint,
    benefit-received: uint,
    redeemed-at: uint,
    applied-to-bill: (optional uint)
  }
)

;; Monthly conservation leaderboard
(define-map conservation-leaderboard
  uint ;; month (block-height / 4320)
  (list 10 { customer: principal, conservation-score: uint })
)

;; Initialize reward catalog
(define-private (init-reward-catalog)
  (begin
    ;; 5% bill discount for 50 points
    (map-set reward-catalog
      u1
      {
        reward-type: REWARD_BILL_DISCOUNT,
        points-cost: u50,
        benefit-amount: u5, ;; 5% discount
        title: "5% Bill Discount",
        description: "Get 5% off your next utility bill",
        active: true
      }
    )
    ;; 10% bill discount for 100 points
    (map-set reward-catalog
      u2
      {
        reward-type: REWARD_BILL_DISCOUNT,
        points-cost: u100,
        benefit-amount: u10, ;; 10% discount
        title: "10% Bill Discount",
        description: "Get 10% off your next utility bill",
        active: true
      }
    )
    ;; Balance credit for 75 points
    (map-set reward-catalog
      u3
      {
        reward-type: REWARD_BALANCE_CREDIT,
        points-cost: u75,
        benefit-amount: u50000, ;; 0.5 STX credit
        title: "Balance Credit",
        description: "Get 0.5 STX added to your account balance",
        active: true
      }
    )
    (var-set next-reward-id u4)
    (ok true)
  )
)

;; Register customer in loyalty program
(define-public (join-loyalty-program)
  (let ((customer tx-sender))
    ;; Check if customer exists in main Utilipay contract
    (asserts! (is-some (contract-call? .Utilipay get-customer customer)) ERR_CUSTOMER_NOT_FOUND)
    (asserts! (is-none (map-get? loyalty-profiles customer)) ERR_UNAUTHORIZED)
    
    (map-set loyalty-profiles
      customer
      {
        total-points: u0,
        available-points: u0,
        tier: TIER_BRONZE,
        consecutive-timely-payments: u0,
        conservation-achievements: u0,
        consistency-score: u0,
        joined-at: stacks-block-height,
        last-activity: stacks-block-height
      }
    )
    (ok true)
  )
)

;; Award points for timely payment
(define-public (award-timely-payment-points (customer principal))
  (let ((profile (unwrap! (map-get? loyalty-profiles customer) ERR_CUSTOMER_NOT_FOUND)))
    ;; Only contract owner can award points
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (let ((new-consecutive (+ (get consecutive-timely-payments profile) u1))
          (bonus-multiplier (if (> new-consecutive u5) u2 u1))
          (points-to-award (* POINTS_TIMELY_PAYMENT bonus-multiplier)))
      
      (update-loyalty-profile customer profile points-to-award new-consecutive 
                             (get conservation-achievements profile) 
                             (get consistency-score profile))
    )
  )
)

;; Award points for energy conservation
(define-public (award-conservation-points (customer principal) (reduction-percentage uint))
  (let ((profile (unwrap! (map-get? loyalty-profiles customer) ERR_CUSTOMER_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (let ((conservation-bonus (if (>= reduction-percentage u20) u2 u1))
          (points-to-award (* POINTS_CONSERVATION conservation-bonus)))
      
      (update-loyalty-profile customer profile points-to-award 
                             (get consecutive-timely-payments profile)
                             (+ (get conservation-achievements profile) u1)
                             (get consistency-score profile))
    )
  )
)

;; Award points for consistent usage patterns
(define-public (award-consistency-points (customer principal))
  (let ((profile (unwrap! (map-get? loyalty-profiles customer) ERR_CUSTOMER_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (update-loyalty-profile customer profile POINTS_CONSISTENCY
                           (get consecutive-timely-payments profile)
                           (get conservation-achievements profile)
                           (+ (get consistency-score profile) u1))
  )
)

;; Helper to update loyalty profile and recalculate tier
(define-private (update-loyalty-profile (customer principal) (profile { total-points: uint, available-points: uint, tier: uint, consecutive-timely-payments: uint, conservation-achievements: uint, consistency-score: uint, joined-at: uint, last-activity: uint }) (points-awarded uint) (consecutive-payments uint) (conservation-count uint) (consistency-score uint))
  (let ((new-total-points (+ (get total-points profile) points-awarded))
        (new-available-points (+ (get available-points profile) points-awarded))
        (new-tier (calculate-tier new-total-points)))
    
    (map-set loyalty-profiles
      customer
      {
        total-points: new-total-points,
        available-points: new-available-points,
        tier: new-tier,
        consecutive-timely-payments: consecutive-payments,
        conservation-achievements: conservation-count,
        consistency-score: consistency-score,
        joined-at: (get joined-at profile),
        last-activity: stacks-block-height
      }
    )
    (ok points-awarded)
  )
)

;; Calculate membership tier based on total points
(define-private (calculate-tier (total-points uint))
  (if (>= total-points PLATINUM_THRESHOLD)
    TIER_PLATINUM
    (if (>= total-points GOLD_THRESHOLD)
      TIER_GOLD
      (if (>= total-points SILVER_THRESHOLD)
        TIER_SILVER
        TIER_BRONZE
      )
    )
  )
)

;; Redeem reward using points
(define-public (redeem-reward (reward-id uint))
  (let ((customer tx-sender)
        (profile (unwrap! (map-get? loyalty-profiles customer) ERR_CUSTOMER_NOT_FOUND))
        (reward (unwrap! (map-get? reward-catalog reward-id) ERR_REWARD_NOT_FOUND))
        (redemption-id (var-get next-reward-id)))
    
    (asserts! (get active reward) ERR_REWARD_NOT_FOUND)
    (asserts! (>= (get available-points profile) (get points-cost reward)) ERR_INSUFFICIENT_POINTS)
    
    (let ((new-available-points (- (get available-points profile) (get points-cost reward))))
      ;; Update customer profile
      (map-set loyalty-profiles
        customer
        (merge profile { 
          available-points: new-available-points,
          last-activity: stacks-block-height 
        })
      )
      
      ;; Record redemption
      (map-set redemption-history
        { customer: customer, redemption-id: redemption-id }
        {
          reward-id: reward-id,
          points-spent: (get points-cost reward),
          benefit-received: (get benefit-amount reward),
          redeemed-at: stacks-block-height,
          applied-to-bill: none
        }
      )
      
      (var-set next-reward-id (+ redemption-id u1))
      
      ;; Apply reward benefit based on type
      (if (is-eq (get reward-type reward) REWARD_BALANCE_CREDIT)
        (begin
          (try! (contract-call? .Utilipay add-balance (get benefit-amount reward)))
          (ok { reward-type: "balance-credit", value: (get benefit-amount reward) })
        )
        (ok { reward-type: "bill-discount", value: (get benefit-amount reward) })
      )
    )
  )
)

;; Reset consecutive payment streak (called when payment is late)
(define-public (reset-payment-streak (customer principal))
  (let ((profile (unwrap! (map-get? loyalty-profiles customer) ERR_CUSTOMER_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set loyalty-profiles
      customer
      (merge profile { 
        consecutive-timely-payments: u0,
        last-activity: stacks-block-height 
      })
    )
    (ok true)
  )
)

;; Add new reward to catalog (contract owner only)
(define-public (add-reward (reward-type uint) (points-cost uint) (benefit-amount uint) (title (string-ascii 30)) (description (string-ascii 100)))
  (let ((reward-id (var-get next-reward-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> points-cost u0) ERR_INVALID_AMOUNT)
    (asserts! (> benefit-amount u0) ERR_INVALID_AMOUNT)
    
    (map-set reward-catalog
      reward-id
      {
        reward-type: reward-type,
        points-cost: points-cost,
        benefit-amount: benefit-amount,
        title: title,
        description: description,
        active: true
      }
    )
    (var-set next-reward-id (+ reward-id u1))
    (ok reward-id)
  )
)

;; Get customer loyalty profile
(define-read-only (get-loyalty-profile (customer principal))
  (map-get? loyalty-profiles customer)
)

;; Get reward details
(define-read-only (get-reward-details (reward-id uint))
  (map-get? reward-catalog reward-id)
)

;; Get customer's redemption history
(define-read-only (get-redemption-history (customer principal) (redemption-id uint))
  (map-get? redemption-history { customer: customer, redemption-id: redemption-id })
)

;; Get tier name as string
(define-read-only (get-tier-name (tier uint))
  (if (is-eq tier TIER_PLATINUM)
    "Platinum"
    (if (is-eq tier TIER_GOLD)
      "Gold"
      (if (is-eq tier TIER_SILVER)
        "Silver"
        "Bronze"
      )
    )
  )
)

;; Calculate points needed for next tier
(define-read-only (get-points-to-next-tier (customer principal))
  (match (map-get? loyalty-profiles customer)
    profile (let ((current-points (get total-points profile))
                  (current-tier (get tier profile)))
      (if (is-eq current-tier TIER_BRONZE)
        (some (- SILVER_THRESHOLD current-points))
        (if (is-eq current-tier TIER_SILVER)
          (some (- GOLD_THRESHOLD current-points))
          (if (is-eq current-tier TIER_GOLD)
            (some (- PLATINUM_THRESHOLD current-points))
            none ;; Already at max tier
          )
        )
      )
    )
    none
  )
)

;; Get all available rewards for customer's tier
(define-read-only (get-available-rewards (customer principal))
  (match (map-get? loyalty-profiles customer)
    profile (let ((customer-tier (get tier profile))
                  (available-points (get available-points profile)))
      (ok {
        customer-tier: customer-tier,
        available-points: available-points,
        tier-name: (get-tier-name customer-tier)
      })
    )
    ERR_CUSTOMER_NOT_FOUND
  )
)

;; Calculate tier benefits multiplier
(define-read-only (get-tier-multiplier (tier uint))
  (if (is-eq tier TIER_PLATINUM)
    u200 ;; 2x multiplier
    (if (is-eq tier TIER_GOLD)
      u150 ;; 1.5x multiplier
      (if (is-eq tier TIER_SILVER)
        u125 ;; 1.25x multiplier
        u100 ;; 1x multiplier (Bronze)
      )
    )
  )
)

;; Check if customer qualifies for conservation bonus
(define-read-only (check-conservation-qualification (customer principal) (current-consumption uint) (previous-consumption uint))
  (if (and (> previous-consumption u0) (< current-consumption previous-consumption))
    (let ((reduction-percentage (/ (* (- previous-consumption current-consumption) u100) previous-consumption)))
      (if (>= reduction-percentage u10) ;; 10% or more reduction
        (some reduction-percentage)
        none
      )
    )
    none
  )
)

;; Get customer loyalty summary
(define-read-only (get-loyalty-summary (customer principal))
  (match (map-get? loyalty-profiles customer)
    profile (ok {
      profile: profile,
      tier-name: (get-tier-name (get tier profile)),
      tier-multiplier: (get-tier-multiplier (get tier profile)),
      points-to-next-tier: (get-points-to-next-tier customer),
      loyalty-score: (calculate-loyalty-score profile)
    })
    ERR_CUSTOMER_NOT_FOUND
  )
)

;; Calculate overall loyalty score
(define-private (calculate-loyalty-score (profile { total-points: uint, available-points: uint, tier: uint, consecutive-timely-payments: uint, conservation-achievements: uint, consistency-score: uint, joined-at: uint, last-activity: uint }))
  (let ((payment-score (* (get consecutive-timely-payments profile) u3))
        (conservation-score (* (get conservation-achievements profile) u5))
        (consistency-score (* (get consistency-score profile) u2))
        (tier-bonus (* (get tier profile) u10)))
    (+ payment-score conservation-score consistency-score tier-bonus)
  )
)

;; Get conservation leaderboard for current month
(define-read-only (get-conservation-leaderboard)
  (let ((current-month (/ stacks-block-height u4320)))
    (default-to (list) (map-get? conservation-leaderboard current-month))
  )
)

;; Check if customer is in top conservation performers (simplified)
(define-read-only (is-top-conservationist (customer principal))
  (let ((current-month (/ stacks-block-height u4320))
        (leaderboard (default-to (list) (map-get? conservation-leaderboard current-month))))
    ;; Simplified: check if leaderboard has entries and customer exists
    (and (> (len leaderboard) u0) (is-some (map-get? loyalty-profiles customer)))
  )
)

;; Update conservation leaderboard
(define-public (update-conservation-leaderboard (customer principal) (conservation-score uint))
  (let ((current-month (/ stacks-block-height u4320))
        (leaderboard (default-to (list) (map-get? conservation-leaderboard current-month)))
        (new-entry { customer: customer, conservation-score: conservation-score }))
    
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (match (as-max-len? (append leaderboard new-entry) u10)
      updated-leaderboard (begin
        (map-set conservation-leaderboard current-month updated-leaderboard)
        (ok true)
      )
      (ok false)
    )
  )
)
