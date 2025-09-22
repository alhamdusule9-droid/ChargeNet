;; ChargeNet Charging Tokens Contract
;; This contract manages prepaid charging tokens for the EV charging network
;; Users can purchase tokens with STX, transfer tokens, and check balances

;; Error constants
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-INSUFFICIENT-BALANCE u2)
(define-constant ERR-INVALID-AMOUNT u3)
(define-constant ERR-TRANSFER-FAILED u4)
(define-constant ERR-ALREADY-EXISTS u5)
(define-constant ERR-NOT-FOUND u6)
(define-constant ERR-INSUFFICIENT-STX u7)

;; Token constants
(define-constant TOKEN-PRICE u1000000) ;; 1 STX = 1,000,000 microSTX per token
(define-constant MIN-PURCHASE u1)      ;; Minimum 1 token purchase
(define-constant MAX-PURCHASE u10000)  ;; Maximum 10,000 tokens per transaction

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Token statistics
(define-data-var total-tokens-issued uint u0)
(define-data-var total-tokens-consumed uint u0)
(define-data-var total-stx-collected uint u0)

;; Token balances for each user
(define-map token-balances principal uint)

;; User purchase history
(define-map purchase-history 
    { user: principal, purchase-id: uint } 
    { amount: uint, stx-paid: uint, block-height: uint }
)

;; Purchase counter for unique IDs
(define-data-var purchase-counter uint u0)

;; Token transfer records
(define-map transfer-records
    { from: principal, to: principal, transfer-id: uint }
    { amount: uint, block-height: uint }
)

;; Transfer counter for unique IDs
(define-data-var transfer-counter uint u0)

;; Authorized charging stations that can consume tokens
(define-map authorized-stations principal bool)

;; PUBLIC FUNCTIONS

;; Purchase charging tokens with STX
(define-public (purchase-tokens (amount uint))
    (let (
        (buyer tx-sender)
        (stx-cost (* amount TOKEN-PRICE))
        (current-balance (default-to u0 (map-get? token-balances buyer)))
        (purchase-id (var-get purchase-counter))
    )
        ;; Validate amount
        (asserts! (and (>= amount MIN-PURCHASE) (<= amount MAX-PURCHASE)) (err ERR-INVALID-AMOUNT))
        
        ;; Transfer STX from buyer to contract
        (try! (stx-transfer? stx-cost buyer (as-contract tx-sender)))
        
        ;; Update buyer's token balance
        (map-set token-balances buyer (+ current-balance amount))
        
        ;; Record purchase history
        (map-set purchase-history 
            { user: buyer, purchase-id: purchase-id }
            { amount: amount, stx-paid: stx-cost, block-height: stacks-block-height }
        )
        
        ;; Update statistics
        (var-set total-tokens-issued (+ (var-get total-tokens-issued) amount))
        (var-set total-stx-collected (+ (var-get total-stx-collected) stx-cost))
        (var-set purchase-counter (+ purchase-id u1))
        
        (print {
            event: "tokens-purchased",
            buyer: buyer,
            amount: amount,
            stx-cost: stx-cost,
            new-balance: (+ current-balance amount)
        })
        
        (ok amount)
    )
)

;; Transfer tokens between users
(define-public (transfer-tokens (to principal) (amount uint))
    (let (
        (sender tx-sender)
        (sender-balance (default-to u0 (map-get? token-balances sender)))
        (receiver-balance (default-to u0 (map-get? token-balances to)))
        (transfer-id (var-get transfer-counter))
    )
        ;; Validate inputs
        (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
        (asserts! (not (is-eq sender to)) (err ERR-INVALID-AMOUNT))
        (asserts! (>= sender-balance amount) (err ERR-INSUFFICIENT-BALANCE))
        
        ;; Update balances
        (map-set token-balances sender (- sender-balance amount))
        (map-set token-balances to (+ receiver-balance amount))
        
        ;; Record transfer
        (map-set transfer-records
            { from: sender, to: to, transfer-id: transfer-id }
            { amount: amount, block-height: stacks-block-height }
        )
        
        (var-set transfer-counter (+ transfer-id u1))
        
        (print {
            event: "tokens-transferred",
            from: sender,
            to: to,
            amount: amount,
            sender-new-balance: (- sender-balance amount),
            receiver-new-balance: (+ receiver-balance amount)
        })
        
        (ok true)
    )
)

;; Consume tokens (only callable by authorized charging stations)
(define-public (consume-tokens (user principal) (amount uint))
    (let (
        (station tx-sender)
        (user-balance (default-to u0 (map-get? token-balances user)))
    )
        ;; Validate station authorization
        (asserts! (default-to false (map-get? authorized-stations station)) (err ERR-NOT-AUTHORIZED))
        (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
        (asserts! (>= user-balance amount) (err ERR-INSUFFICIENT-BALANCE))
        
        ;; Deduct tokens from user balance
        (map-set token-balances user (- user-balance amount))
        
        ;; Update consumption statistics
        (var-set total-tokens-consumed (+ (var-get total-tokens-consumed) amount))
        
        (print {
            event: "tokens-consumed",
            user: user,
            station: station,
            amount: amount,
            remaining-balance: (- user-balance amount)
        })
        
        (ok amount)
    )
)

;; Authorize a charging station to consume tokens (owner only)
(define-public (authorize-station (station principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
        (map-set authorized-stations station true)
        
        (print {
            event: "station-authorized",
            station: station
        })
        
        (ok true)
    )
)

;; Revoke station authorization (owner only)
(define-public (revoke-station-auth (station principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
        (map-delete authorized-stations station)
        
        (print {
            event: "station-authorization-revoked",
            station: station
        })
        
        (ok true)
    )
)

;; Transfer contract ownership (owner only)
(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
        (var-set contract-owner new-owner)
        
        (print {
            event: "ownership-transferred",
            old-owner: tx-sender,
            new-owner: new-owner
        })
        
        (ok true)
    )
)

;; READ-ONLY FUNCTIONS

;; Get token balance for a user
(define-read-only (get-balance (user principal))
    (default-to u0 (map-get? token-balances user))
)

;; Get contract owner
(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

;; Get token price in microSTX
(define-read-only (get-token-price)
    TOKEN-PRICE
)

;; Get total tokens issued
(define-read-only (get-total-issued)
    (var-get total-tokens-issued)
)

;; Get total tokens consumed
(define-read-only (get-total-consumed)
    (var-get total-tokens-consumed)
)

;; Get total STX collected
(define-read-only (get-total-stx-collected)
    (var-get total-stx-collected)
)

;; Get circulating token supply
(define-read-only (get-circulating-supply)
    (- (var-get total-tokens-issued) (var-get total-tokens-consumed))
)

;; Check if station is authorized
(define-read-only (is-station-authorized (station principal))
    (default-to false (map-get? authorized-stations station))
)

;; Get purchase history for a user
(define-read-only (get-purchase-history (user principal) (purchase-id uint))
    (map-get? purchase-history { user: user, purchase-id: purchase-id })
)

;; Get transfer record
(define-read-only (get-transfer-record (from principal) (to principal) (transfer-id uint))
    (map-get? transfer-records { from: from, to: to, transfer-id: transfer-id })
)

;; Calculate STX cost for token amount
(define-read-only (calculate-cost (amount uint))
    (* amount TOKEN-PRICE)
)

;; Get current purchase counter
(define-read-only (get-purchase-counter)
    (var-get purchase-counter)
)

;; Get current transfer counter
(define-read-only (get-transfer-counter)
    (var-get transfer-counter)
)
