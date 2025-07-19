;; Implements a bounty hunting system where hunters can accept bounties
;; with reward escrow, dispute resolution, and objective tracking

;; Constants
(define-constant guild-master tx-sender)
(define-constant bounty-status-posted u0)
(define-constant bounty-status-accepted u1)
(define-constant bounty-status-completed u2)
(define-constant bounty-status-cancelled u3)
(define-constant bounty-status-disputed u4)

;; Error constants
(define-constant ERROR_UNAUTHORIZED_HUNTER (err u100))
(define-constant ERROR_INVALID_BOUNTY_STATUS (err u101))
(define-constant ERROR_INSUFFICIENT_REWARD (err u102))
(define-constant ERROR_BOUNTY_ALREADY_EXISTS (err u103))
(define-constant ERROR_BOUNTY_NOT_FOUND (err u104))
(define-constant ERROR_INVALID_OBJECTIVE_INDEX (err u105))
(define-constant ERROR_INVALID_INPUT (err u106))
(define-constant ERROR_INVALID_HUNTER_ADDRESS (err u107))
(define-constant ERROR_INVALID_OBJECTIVE_DATA (err u108))

;; Data structures
(define-map bounty-board
    { bounty-id: uint }
    {
        hunter-address: principal,
        poster-address: principal,
        total-reward-amount: uint,
        bounty-status: uint,
        hunt-start-block: uint,
        hunt-deadline-block: uint,
        dispute-deadline-block: uint,
        hunt-objectives: (list 5 {
            objective-description: (string-utf8 100),
            objective-reward: uint,
            objective-completed: bool
        })
    }
)

(define-map reward-vault
    { bounty-id: uint }
    { locked-rewards: uint }
)

(define-map bounty-disputes
    { bounty-id: uint }
    {
        dispute-details: (string-utf8 200),
        dispute-filer: principal,
        guild-ruling: (optional (string-utf8 200))
    }
)

;; Read-only functions
(define-read-only (get-bounty-info (bounty-id uint))
    (map-get? bounty-board { bounty-id: bounty-id })
)

(define-read-only (get-locked-rewards (bounty-id uint))
    (default-to { locked-rewards: u0 }
        (map-get? reward-vault { bounty-id: bounty-id })
    )
)

(define-read-only (get-dispute-info (bounty-id uint))
    (map-get? bounty-disputes { bounty-id: bounty-id })
)

;; Private functions
(define-private (verify-bounty-participant (bounty-id uint))
    (let ((bounty-data (unwrap! (get-bounty-info bounty-id) false)))
        (or
            (is-eq tx-sender guild-master)
            (is-eq tx-sender (get hunter-address bounty-data))
            (is-eq tx-sender (get poster-address bounty-data))
        )
    )
)

(define-private (objective-completed? (objective {
    objective-description: (string-utf8 100),
    objective-reward: uint,
    objective-completed: bool
}))
    (get objective-completed objective))

(define-private (verify-all-objectives-complete (hunt-objectives (list 5 {
        objective-description: (string-utf8 100),
        objective-reward: uint,
        objective-completed: bool
    })))
    (and
        (objective-completed? (unwrap-panic (element-at hunt-objectives u0)))
        (objective-completed? (unwrap-panic (element-at hunt-objectives u1)))
        (objective-completed? (unwrap-panic (element-at hunt-objectives u2)))
        (objective-completed? (unwrap-panic (element-at hunt-objectives u3)))
        (objective-completed? (unwrap-panic (element-at hunt-objectives u4)))
    )
)

(define-private (validate-hunter-address (hunter principal))
    (and 
        (not (is-eq hunter tx-sender))  ;; Hunter cannot be the poster
        (not (is-eq hunter guild-master))  ;; Hunter cannot be the guild master
        (not (is-eq hunter (as-contract tx-sender)))  ;; Hunter cannot be the contract itself
    )
)

(define-private (validate-objective-rewards (objectives (list 5 {
        objective-description: (string-utf8 100),
        objective-reward: uint,
        objective-completed: bool
    })) 
    (total-reward uint))
    (let ((total-objective-rewards (+ 
            (get objective-reward (unwrap-panic (element-at objectives u0)))
            (get objective-reward (unwrap-panic (element-at objectives u1)))
            (get objective-reward (unwrap-panic (element-at objectives u2)))
            (get objective-reward (unwrap-panic (element-at objectives u3)))
            (get objective-reward (unwrap-panic (element-at objectives u4)))
        )))
        (and 
            (is-eq total-objective-rewards total-reward)  ;; Sum of objective rewards must equal total reward
            (> (len (get objective-description (unwrap-panic (element-at objectives u0)))) u0)  ;; Validate descriptions
            (> (len (get objective-description (unwrap-panic (element-at objectives u1)))) u0)
            (> (len (get objective-description (unwrap-panic (element-at objectives u2)))) u0)
            (> (len (get objective-description (unwrap-panic (element-at objectives u3)))) u0)
            (> (len (get objective-description (unwrap-panic (element-at objectives u4)))) u0)
        )
    )
)

(define-private (update-objective-at-index 
    (objective {
        objective-description: (string-utf8 100),
        objective-reward: uint,
        objective-completed: bool
    })
    (target-index uint)
    (index uint))
    {
        objective-description: (get objective-description objective),
        objective-reward: (get objective-reward objective),
        objective-completed: (if (is-eq index target-index) 
                               true 
                               (get objective-completed objective))
    }
)

;; Public functions
(define-public (post-bounty (bounty-id uint) 
                           (hunter-address principal)
                           (total-reward-amount uint)
                           (hunt-duration uint)
                           (hunt-objectives (list 5 {
                               objective-description: (string-utf8 100),
                               objective-reward: uint,
                               objective-completed: bool
                           })))
    (let ((current-block block-height))
        (asserts! (is-none (get-bounty-info bounty-id)) ERROR_BOUNTY_ALREADY_EXISTS)
        (asserts! (> total-reward-amount u0) ERROR_INSUFFICIENT_REWARD)
        (asserts! (> hunt-duration u0) ERROR_INVALID_INPUT)
        (asserts! (validate-hunter-address hunter-address) ERROR_INVALID_HUNTER_ADDRESS)
        (asserts! (validate-objective-rewards hunt-objectives total-reward-amount) ERROR_INVALID_OBJECTIVE_DATA)
        
        (map-set bounty-board
            { bounty-id: bounty-id }
            {
                hunter-address: hunter-address,
                poster-address: tx-sender,
                total-reward-amount: total-reward-amount,
                bounty-status: bounty-status-posted,
                hunt-start-block: current-block,
                hunt-deadline-block: (+ current-block hunt-duration),
                dispute-deadline-block: (+ (+ current-block hunt-duration) u144), ;; ~1 day after deadline (assuming ~10min blocks)
                hunt-objectives: hunt-objectives
            }
        )
        
        (map-set reward-vault
            { bounty-id: bounty-id }
            { locked-rewards: u0 }
        )
        
        (ok true)
    )
)

(define-public (fund-bounty (bounty-id uint) (reward-amount uint))
    (let ((bounty-data (unwrap! (get-bounty-info bounty-id) ERROR_BOUNTY_NOT_FOUND))
          (current-vault-balance (get locked-rewards (get-locked-rewards bounty-id))))
        
        (asserts! (is-eq tx-sender (get poster-address bounty-data)) ERROR_UNAUTHORIZED_HUNTER)
        (asserts! (is-eq (get bounty-status bounty-data) bounty-status-posted) ERROR_INVALID_BOUNTY_STATUS)
        (asserts! (> reward-amount u0) ERROR_INVALID_INPUT)
        
        (try! (stx-transfer? reward-amount tx-sender (as-contract tx-sender)))
        
        (let ((new-vault-balance (+ current-vault-balance reward-amount)))
            (map-set reward-vault
                { bounty-id: bounty-id }
                { locked-rewards: new-vault-balance }
            )
            
            (if (>= new-vault-balance (get total-reward-amount bounty-data))
                (map-set bounty-board
                    { bounty-id: bounty-id }
                    (merge bounty-data { bounty-status: bounty-status-accepted })
                )
                true
            )
            
            (ok true)
        )
    )
)

(define-public (complete-objective (bounty-id uint) (objective-index uint))
    (let ((bounty-data (unwrap! (get-bounty-info bounty-id) ERROR_BOUNTY_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get hunter-address bounty-data)) ERROR_UNAUTHORIZED_HUNTER)
        (asserts! (is-eq (get bounty-status bounty-data) bounty-status-accepted) ERROR_INVALID_BOUNTY_STATUS)
        (asserts! (< objective-index (len (get hunt-objectives bounty-data))) ERROR_INVALID_OBJECTIVE_INDEX)
        
        (let ((objectives (get hunt-objectives bounty-data))
              (updated-hunt-objectives 
                (list 
                    (update-objective-at-index (unwrap-panic (element-at objectives u0)) objective-index u0)
                    (update-objective-at-index (unwrap-panic (element-at objectives u1)) objective-index u1)
                    (update-objective-at-index (unwrap-panic (element-at objectives u2)) objective-index u2)
                    (update-objective-at-index (unwrap-panic (element-at objectives u3)) objective-index u3)
                    (update-objective-at-index (unwrap-panic (element-at objectives u4)) objective-index u4)
                )))
            
            (map-set bounty-board
                { bounty-id: bounty-id }
                (merge bounty-data { hunt-objectives: updated-hunt-objectives })
            )
            
            (if (verify-all-objectives-complete updated-hunt-objectives)
                (map-set bounty-board
                    { bounty-id: bounty-id }
                    (merge bounty-data { 
                        bounty-status: bounty-status-completed,
                        hunt-objectives: updated-hunt-objectives 
                    })
                )
                true
            )
            
            (ok true)
        )
    )
)

(define-public (claim-bounty-rewards (bounty-id uint))
    (let ((bounty-data (unwrap! (get-bounty-info bounty-id) ERROR_BOUNTY_NOT_FOUND))
          (vault-data (get-locked-rewards bounty-id)))
        
        (asserts! (is-eq tx-sender (get poster-address bounty-data)) ERROR_UNAUTHORIZED_HUNTER)
        (asserts! (is-eq (get bounty-status bounty-data) bounty-status-completed) ERROR_INVALID_BOUNTY_STATUS)
        
        (try! (as-contract (stx-transfer? 
            (get locked-rewards vault-data)
            (as-contract tx-sender)
            (get hunter-address bounty-data)
        )))
        
        (map-set reward-vault
            { bounty-id: bounty-id }
            { locked-rewards: u0 }
        )
        
        (ok true)
    )
)

(define-public (file-bounty-dispute (bounty-id uint) (dispute-details (string-utf8 200)))
    (let ((bounty-data (unwrap! (get-bounty-info bounty-id) ERROR_BOUNTY_NOT_FOUND)))
        (asserts! (verify-bounty-participant bounty-id) ERROR_UNAUTHORIZED_HUNTER)
        (asserts! (< block-height (get dispute-deadline-block bounty-data)) ERROR_INVALID_BOUNTY_STATUS)
        (asserts! (> (len dispute-details) u0) ERROR_INVALID_INPUT)
        
        (map-set bounty-disputes
            { bounty-id: bounty-id }
            {
                dispute-details: dispute-details,
                dispute-filer: tx-sender,
                guild-ruling: none
            }
        )
        
        (map-set bounty-board
            { bounty-id: bounty-id }
            (merge bounty-data { bounty-status: bounty-status-disputed })
        )
        
        (ok true)
    )
)

(define-public (issue-guild-ruling (bounty-id uint) 
                                  (ruling-details (string-utf8 200))
                                  (poster-refund-percentage uint))
    (let ((bounty-data (unwrap! (get-bounty-info bounty-id) ERROR_BOUNTY_NOT_FOUND))
          (vault-data (get-locked-rewards bounty-id)))
        
        (asserts! (is-eq tx-sender guild-master) ERROR_UNAUTHORIZED_HUNTER)
        (asserts! (is-eq (get bounty-status bounty-data) bounty-status-disputed) ERROR_INVALID_BOUNTY_STATUS)
        (asserts! (<= poster-refund-percentage u100) ERROR_INVALID_INPUT)
        (asserts! (> (len ruling-details) u0) ERROR_INVALID_INPUT)
        
        (let ((poster-refund-amount (/ (* (get locked-rewards vault-data) poster-refund-percentage) u100))
              (hunter-reward-amount (- (get locked-rewards vault-data) poster-refund-amount)))
            
            ;; Process poster refund
            (if (> poster-refund-amount u0)
                (try! (as-contract (stx-transfer? 
                    poster-refund-amount
                    (as-contract tx-sender)
                    (get poster-address bounty-data)
                )))
                true
            )
            
            ;; Process hunter reward
            (if (> hunter-reward-amount u0)
                (try! (as-contract (stx-transfer? 
                    hunter-reward-amount
                    (as-contract tx-sender)
                    (get hunter-address bounty-data)
                )))
                true
            )
            
            ;; Update dispute ruling
            (let ((dispute-data (unwrap! (get-dispute-info bounty-id) ERROR_BOUNTY_NOT_FOUND)))
                (map-set bounty-disputes
                    { bounty-id: bounty-id }
                    (merge dispute-data { guild-ruling: (some ruling-details) })
                )
            )
            
            ;; Clear vault and update status
            (map-set reward-vault
                { bounty-id: bounty-id }
                { locked-rewards: u0 }
            )
            
            (map-set bounty-board
                { bounty-id: bounty-id }
                (merge bounty-data { bounty-status: bounty-status-completed })
            )
            
            (ok true)
        )
    )
)

(define-public (cancel-bounty (bounty-id uint))
    (let ((bounty-data (unwrap! (get-bounty-info bounty-id) ERROR_BOUNTY_NOT_FOUND))
          (vault-data (get-locked-rewards bounty-id)))
        
        (asserts! (verify-bounty-participant bounty-id) ERROR_UNAUTHORIZED_HUNTER)
        (asserts! (is-eq (get bounty-status bounty-data) bounty-status-posted) ERROR_INVALID_BOUNTY_STATUS)
        
        ;; Return locked rewards to poster
        (if (> (get locked-rewards vault-data) u0)
            (try! (as-contract (stx-transfer? 
                (get locked-rewards vault-data)
                (as-contract tx-sender)
                (get poster-address bounty-data)
            )))
            true
        )
        
        (map-set reward-vault
            { bounty-id: bounty-id }
            { locked-rewards: u0 }
        )
        
        (map-set bounty-board
            { bounty-id: bounty-id }
            (merge bounty-data { bounty-status: bounty-status-cancelled })
        )
        
        (ok true)
    )
)