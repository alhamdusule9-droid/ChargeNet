;; ChargeNet Charging Station Contract
;; This contract manages charging stations, sessions, and token consumption
;; Stations can register, manage charging sessions, and consume user tokens

;; Error constants
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-STATION-NOT-FOUND u2)
(define-constant ERR-STATION-INACTIVE u3)
(define-constant ERR-SESSION-NOT-FOUND u4)
(define-constant ERR-SESSION-ALREADY-ACTIVE u5)
(define-constant ERR-SESSION-ALREADY-ENDED u6)
(define-constant ERR-INVALID-AMOUNT u7)
(define-constant ERR-INSUFFICIENT-TOKENS u8)
(define-constant ERR-ALREADY-REGISTERED u9)
(define-constant ERR-INVALID-STATION u10)

;; Station status constants
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-INACTIVE u2)
(define-constant STATUS-MAINTENANCE u3)

;; Session status constants
(define-constant SESSION-ACTIVE u1)
(define-constant SESSION-COMPLETED u2)
(define-constant SESSION-CANCELLED u3)

;; Pricing constants
(define-constant BASE-RATE u100)          ;; 100 tokens per hour base rate
(define-constant FAST-CHARGE-MULTIPLIER u2) ;; 2x rate for fast charging
(define-constant MIN-SESSION-TOKENS u10)    ;; Minimum 10 tokens to start session

;; Contract references (will be resolved at deployment)
;; (define-constant TOKENS-CONTRACT 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.charging-tokens)

;; Data variables
(define-data-var network-admin principal tx-sender)
(define-data-var station-counter uint u0)
(define-data-var session-counter uint u0)
(define-data-var total-energy-delivered uint u0)
(define-data-var total-sessions-completed uint u0)

;; Station registry
(define-map stations
    principal
    {
        station-id: uint,
        operator: principal,
        location: (string-ascii 100),
        charge-type: (string-ascii 20),
        power-rating: uint,
        status: uint,
        rate-per-hour: uint,
        total-sessions: uint,
        total-energy: uint,
        registration-block: uint
    }
)

;; Active charging sessions
(define-map charging-sessions
    uint
    {
        session-id: uint,
        station: principal,
        user: principal,
        start-time: uint,
        end-time: (optional uint),
        tokens-consumed: uint,
        energy-delivered: uint,
        status: uint
    }
)

;; User session history
(define-map user-sessions
    { user: principal, session-index: uint }
    uint
)

;; User session counters
(define-map user-session-counters principal uint)

;; Station earnings
(define-map station-earnings principal uint)

;; Station operator authorization
(define-map authorized-operators principal bool)

;; PUBLIC FUNCTIONS

;; Register a new charging station
(define-public (register-station 
    (location (string-ascii 100)) 
    (charge-type (string-ascii 20)) 
    (power-rating uint) 
    (rate-per-hour uint))
    (let (
        (station-operator tx-sender)
        (station-id (+ (var-get station-counter) u1))
    )
        ;; Check if station already registered
        (asserts! (is-none (map-get? stations station-operator)) (err ERR-ALREADY-REGISTERED))
        (asserts! (> power-rating u0) (err ERR-INVALID-AMOUNT))
        (asserts! (> rate-per-hour u0) (err ERR-INVALID-AMOUNT))
        
        ;; Register the station
        (map-set stations station-operator {
            station-id: station-id,
            operator: station-operator,
            location: location,
            charge-type: charge-type,
            power-rating: power-rating,
            status: STATUS-ACTIVE,
            rate-per-hour: rate-per-hour,
            total-sessions: u0,
            total-energy: u0,
            registration-block: stacks-block-height
        })
        
        ;; Authorize station operator
        (map-set authorized-operators station-operator true)
        
        ;; Update counter
        (var-set station-counter station-id)
        
        (print {
            event: "station-registered",
            station: station-operator,
            station-id: station-id,
            location: location,
            charge-type: charge-type,
            power-rating: power-rating,
            rate: rate-per-hour
        })
        
        (ok station-id)
    )
)

;; Start a charging session
(define-public (start-session (station principal))
    (let (
        (user tx-sender)
        (session-id (+ (var-get session-counter) u1))
        (station-data (unwrap! (map-get? stations station) (err ERR-STATION-NOT-FOUND)))
        (user-session-count (default-to u0 (map-get? user-session-counters user)))
    )
        ;; Validate station status
        (asserts! (is-eq (get status station-data) STATUS-ACTIVE) (err ERR-STATION-INACTIVE))
        
        ;; Check if user has sufficient tokens for minimum session
        ;; Note: In production, this would check user balance via cross-contract call
        ;; (asserts! (>= 
        ;;     (unwrap-panic (contract-call? .charging-tokens get-balance user))
        ;;     MIN-SESSION-TOKENS
        ;; ) (err ERR-INSUFFICIENT-TOKENS))
        
        ;; Create charging session
        (map-set charging-sessions session-id {
            session-id: session-id,
            station: station,
            user: user,
            start-time: stacks-block-height,
            end-time: none,
            tokens-consumed: u0,
            energy-delivered: u0,
            status: SESSION-ACTIVE
        })
        
        ;; Update user session tracking
        (map-set user-sessions { user: user, session-index: user-session-count } session-id)
        (map-set user-session-counters user (+ user-session-count u1))
        
        ;; Update counter
        (var-set session-counter session-id)
        
        (print {
            event: "session-started",
            session-id: session-id,
            station: station,
            user: user,
            start-block: stacks-block-height
        })
        
        (ok session-id)
    )
)

;; End charging session and consume tokens
(define-public (end-session (session-id uint) (energy-delivered uint))
    (let (
        (session-data (unwrap! (map-get? charging-sessions session-id) (err ERR-SESSION-NOT-FOUND)))
        (station (get station session-data))
        (user (get user session-data))
        (station-data (unwrap! (map-get? stations station) (err ERR-STATION-NOT-FOUND)))
        (session-duration (- stacks-block-height (get start-time session-data)))
        (base-tokens (/ (* (get rate-per-hour station-data) session-duration) u144)) ;; Estimate blocks per hour
        (energy-factor (if (> energy-delivered u1000) FAST-CHARGE-MULTIPLIER u1))
        (tokens-to-consume (* base-tokens energy-factor))
        (current-earnings (default-to u0 (map-get? station-earnings station)))
    )
        ;; Validate session and caller
        (asserts! (is-eq tx-sender station) (err ERR-NOT-AUTHORIZED))
        (asserts! (is-eq (get status session-data) SESSION-ACTIVE) (err ERR-SESSION-ALREADY-ENDED))
        (asserts! (> energy-delivered u0) (err ERR-INVALID-AMOUNT))
        
        ;; Consume tokens from user
        ;; Note: In production, this would consume tokens via cross-contract call
        ;; (try! (contract-call? .charging-tokens consume-tokens user tokens-to-consume))
        
        ;; Update session data
        (map-set charging-sessions session-id (merge session-data {
            end-time: (some stacks-block-height),
            tokens-consumed: tokens-to-consume,
            energy-delivered: energy-delivered,
            status: SESSION-COMPLETED
        }))
        
        ;; Update station statistics
        (map-set stations station (merge station-data {
            total-sessions: (+ (get total-sessions station-data) u1),
            total-energy: (+ (get total-energy station-data) energy-delivered)
        }))
        
        ;; Update station earnings
        (map-set station-earnings station (+ current-earnings tokens-to-consume))
        
        ;; Update network statistics
        (var-set total-energy-delivered (+ (var-get total-energy-delivered) energy-delivered))
        (var-set total-sessions-completed (+ (var-get total-sessions-completed) u1))
        
        (print {
            event: "session-completed",
            session-id: session-id,
            station: station,
            user: user,
            duration: session-duration,
            energy-delivered: energy-delivered,
            tokens-consumed: tokens-to-consume
        })
        
        (ok tokens-to-consume)
    )
)

;; Update station status (operator only)
(define-public (update-station-status (new-status uint))
    (let (
        (operator tx-sender)
        (station-data (unwrap! (map-get? stations operator) (err ERR-STATION-NOT-FOUND)))
    )
        ;; Validate status
        (asserts! (or (is-eq new-status STATUS-ACTIVE) 
                     (or (is-eq new-status STATUS-INACTIVE) 
                         (is-eq new-status STATUS-MAINTENANCE))) (err ERR-INVALID-AMOUNT))
        
        ;; Update station status
        (map-set stations operator (merge station-data { status: new-status }))
        
        (print {
            event: "station-status-updated",
            station: operator,
            new-status: new-status
        })
        
        (ok true)
    )
)

;; Update station rate (operator only)
(define-public (update-station-rate (new-rate uint))
    (let (
        (operator tx-sender)
        (station-data (unwrap! (map-get? stations operator) (err ERR-STATION-NOT-FOUND)))
    )
        (asserts! (> new-rate u0) (err ERR-INVALID-AMOUNT))
        
        ;; Update station rate
        (map-set stations operator (merge station-data { rate-per-hour: new-rate }))
        
        (print {
            event: "station-rate-updated",
            station: operator,
            new-rate: new-rate
        })
        
        (ok true)
    )
)

;; Emergency session cancellation (admin only)
(define-public (cancel-session (session-id uint))
    (let (
        (session-data (unwrap! (map-get? charging-sessions session-id) (err ERR-SESSION-NOT-FOUND)))
    )
        (asserts! (is-eq tx-sender (var-get network-admin)) (err ERR-NOT-AUTHORIZED))
        (asserts! (is-eq (get status session-data) SESSION-ACTIVE) (err ERR-SESSION-ALREADY-ENDED))
        
        ;; Update session status
        (map-set charging-sessions session-id (merge session-data {
            end-time: (some stacks-block-height),
            status: SESSION-CANCELLED
        }))
        
        (print {
            event: "session-cancelled",
            session-id: session-id,
            admin: tx-sender
        })
        
        (ok true)
    )
)

;; READ-ONLY FUNCTIONS

;; Get station information
(define-read-only (get-station-info (station principal))
    (map-get? stations station)
)

;; Get session information
(define-read-only (get-session-info (session-id uint))
    (map-get? charging-sessions session-id)
)

;; Get user's session by index
(define-read-only (get-user-session (user principal) (session-index uint))
    (map-get? user-sessions { user: user, session-index: session-index })
)

;; Get user's total sessions
(define-read-only (get-user-session-count (user principal))
    (default-to u0 (map-get? user-session-counters user))
)

;; Get station earnings
(define-read-only (get-station-earnings (station principal))
    (default-to u0 (map-get? station-earnings station))
)

;; Get network statistics
(define-read-only (get-network-stats)
    {
        total-stations: (var-get station-counter),
        total-sessions: (var-get session-counter),
        total-energy-delivered: (var-get total-energy-delivered),
        completed-sessions: (var-get total-sessions-completed)
    }
)

;; Check if operator is authorized
(define-read-only (is-authorized-operator (operator principal))
    (default-to false (map-get? authorized-operators operator))
)

;; Calculate session cost estimate
(define-read-only (estimate-session-cost (station principal) (estimated-duration uint) (estimated-energy uint))
    (match (map-get? stations station)
        station-data
        (let (
            (base-cost (* (get rate-per-hour station-data) (/ estimated-duration u144)))
            (energy-multiplier (if (> estimated-energy u1000) FAST-CHARGE-MULTIPLIER u1))
        )
            (ok (* base-cost energy-multiplier))
        )
        (err ERR-STATION-NOT-FOUND)
    )
)

;; Get network admin
(define-read-only (get-network-admin)
    (var-get network-admin)
)

;; Get active sessions for a station
(define-read-only (get-station-active-sessions (station principal))
    (var-get session-counter) ;; Simplified - would need iteration in full implementation
)

;; Get minimum session tokens
(define-read-only (get-min-session-tokens)
    MIN-SESSION-TOKENS
)
