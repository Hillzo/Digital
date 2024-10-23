;; Enhanced Digital Will Smart Contract
;; Implements complete asset transfer logic, events, backup executors, and granular permissions

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-WILL-EXISTS (err u101))
(define-constant ERR-WILL-NOT-FOUND (err u102))
(define-constant ERR-INVALID-BENEFICIARY-DATA (err u103))
(define-constant ERR-WILL-ALREADY-EXECUTED (err u104))
(define-constant ERR-WILL-INACTIVE (err u105))
(define-constant ERR-INVALID-EXECUTOR (err u106))
(define-constant ERR-INVALID-PERIOD (err u107))
(define-constant ERR-TRANSFER-FAILED (err u108))

;; Events
(define-data-var event-counter uint u0)

(define-map events
    { event-id: uint }
    {
        event-type: (string-utf8 24),
        timestamp: uint,
        initiator: principal,
        details: (string-utf8 256)
    }
)

;; Data structures
(define-map digital-wills
    { testator: principal }
    {
        beneficiary-list: (list 20 { recipient: principal, allocation: uint }),
        backup-executors: (list 3 principal),
        is-active: bool,
        is-executed: bool,
        last-activity: uint,
        inactivity-threshold: uint,
        stx-assets: (list 10 { amount: uint }),
        ft-assets: (list 10 { token-contract: principal, amount: uint }),
        nft-assets: (list 10 { nft-contract: principal, token-id: uint })
    }
)

;; Asset transfer traits
(define-trait ft-trait
    (
        (transfer (uint principal principal) (response bool uint))
    )
)

(define-trait nft-trait
    (
        (transfer (uint principal principal) (response bool uint))
    )
)

;; Event logging function
(define-private (log-event (event-type (string-utf8 24)) (initiator principal) (details (string-utf8 256)))
    (let
        (
            (current-id (var-get event-counter))
            (next-id (+ current-id u1))
        )
        (var-set event-counter next-id)
        (map-set events
            { event-id: current-id }
            {
                event-type: event-type,
                timestamp: (unwrap-panic (get-block-info? time u0)),
                initiator: initiator,
                details: details
            }
        )
        (ok current-id)
    )
)

;; Read-only functions
(define-read-only (get-digital-will (testator principal))
    (map-get? digital-wills { testator: testator })
)

(define-read-only (get-event (event-id uint))
    (map-get? events { event-id: event-id })
)

(define-read-only (check-will-status (testator principal))
    (match (map-get? digital-wills { testator: testator })
        will (let
            (
                (current-time (unwrap-panic (get-block-info? time u0)))
                (last-activity (get last-activity will))
                (threshold (get inactivity-threshold will))
            )
            (ok {
                is-active: (get is-active will),
                is-executed: (get is-executed will),
                inactive-duration: (- current-time last-activity),
                can-execute: (> (- current-time last-activity) threshold)
            })
        )
        error (err ERR-WILL-NOT-FOUND)
    )
)

;; Asset transfer functions
(define-private (transfer-stx-asset (recipient principal) (amount uint))
    (stx-transfer? amount tx-sender recipient)
)

(define-private (transfer-ft-asset (token-contract principal) (recipient principal) (amount uint))
    (contract-call? token-contract transfer amount tx-sender recipient)
)

(define-private (transfer-nft-asset (nft-contract principal) (recipient principal) (token-id uint))
    (contract-call? nft-contract transfer token-id tx-sender recipient)
)

;; Public functions
(define-public (create-digital-will
    (beneficiary-list (list 20 { recipient: principal, allocation: uint }))
    (backup-executors (list 3 principal))
    (inactivity-threshold uint)
    (stx-assets (list 10 { amount: uint }))
    (ft-assets (list 10 { token-contract: principal, amount: uint }))
    (nft-assets (list 10 { nft-contract: principal, token-id: uint })))
    
    (let ((testator tx-sender))
        (asserts! (is-none (map-get? digital-wills { testator: testator })) (err ERR-WILL-EXISTS))
        (asserts! (> (len beneficiary-list) u0) (err ERR-INVALID-BENEFICIARY-DATA))
        (asserts! (>= inactivity-threshold u1) (err ERR-INVALID-PERIOD))
        
        (map-set digital-wills
            { testator: testator }
            {
                beneficiary-list: beneficiary-list,
                backup-executors: backup-executors,
                is-active: true,
                is-executed: false,
                last-activity: (unwrap-panic (get-block-info? time u0)),
                inactivity-threshold: inactivity-threshold,
                stx-assets: stx-assets,
                ft-assets: ft-assets,
                nft-assets: nft-assets
            }
        )
        (unwrap-panic (log-event "WILL_CREATED" testator "Digital will created successfully"))
        (ok true)
    )
)

(define-public (update-inactivity-threshold (new-threshold uint))
    (let ((testator tx-sender))
        (match (map-get? digital-wills { testator: testator })
            will (begin
                (asserts! (not (get is-executed will)) (err ERR-WILL-ALREADY-EXECUTED))
                (asserts! (>= new-threshold u1) (err ERR-INVALID-PERIOD))
                
                (map-set digital-wills
                    { testator: testator }
                    (merge will { inactivity-threshold: new-threshold })
                )
                (unwrap-panic (log-event "THRESHOLD_UPDATED" testator "Inactivity threshold updated"))
                (ok true)
            )
            error (err ERR-WILL-NOT-FOUND)
        )
    )
)

(define-public (update-backup-executors (new-executors (list 3 principal)))
    (let ((testator tx-sender))
        (match (map-get? digital-wills { testator: testator })
            will (begin
                (asserts! (not (get is-executed will)) (err ERR-WILL-ALREADY-EXECUTED))
                
                (map-set digital-wills
                    { testator: testator }
                    (merge will { backup-executors: new-executors })
                )
                (unwrap-panic (log-event "EXECUTORS_UPDATED" testator "Backup executors updated"))
                (ok true)
            )
            error (err ERR-WILL-NOT-FOUND)
        )
    )
)

(define-public (record-activity)
    (let ((testator tx-sender))
        (match (map-get? digital-wills { testator: testator })
            will (begin
                (asserts! (not (get is-executed will)) (err ERR-WILL-ALREADY-EXECUTED))
                (asserts! (get is-active will) (err ERR-WILL-INACTIVE))
                
                (map-set digital-wills
                    { testator: testator }
                    (merge will { last-activity: (unwrap-panic (get-block-info? time u0)) })
                )
                (unwrap-panic (log-event "ACTIVITY_RECORDED" testator "Activity timestamp updated"))
                (ok true)
            )
            error (err ERR-WILL-NOT-FOUND)
        )
    )
)

(define-public (execute-digital-will (testator principal))
    (let (
        (executor tx-sender)
        (will (unwrap! (map-get? digital-wills { testator: testator }) (err ERR-WILL-NOT-FOUND)))
        (current-time (unwrap-panic (get-block-info? time u0)))
    )
        ;; Verify execution conditions
        (asserts! (get is-active will) (err ERR-WILL-INACTIVE))
        (asserts! (not (get is-executed will)) (err ERR-WILL-ALREADY-EXECUTED))
        (asserts! (or
            (is-some (index-of (get backup-executors will) executor))
            (> (- current-time (get last-activity will)) (get inactivity-threshold will))
        ) (err ERR-UNAUTHORIZED))
        
        ;; Execute STX transfers
        (map transfer-stx-asset
            (get beneficiary-list will)
            (get stx-assets will)
        )
        
        ;; Execute FT transfers
        (map transfer-ft-asset
            (get ft-assets will)
            (get beneficiary-list will)
        )
        
        ;; Execute NFT transfers
        (map transfer-nft-asset
            (get nft-assets will)
            (get beneficiary-list will)
        )
        
        ;; Mark will as executed
        (map-set digital-wills
            { testator: testator }
            (merge will { 
                is-executed: true,
                is-active: false
            })
        )
        
        (unwrap-panic (log-event "WILL_EXECUTED" executor "Digital will executed successfully"))
        (ok true)
    )
)

(define-public (revoke-digital-will)
    (let ((testator tx-sender))
        (match (map-get? digital-wills { testator: testator })
            will (begin
                (asserts! (not (get is-executed will)) (err ERR-WILL-ALREADY-EXECUTED))
                
                (map-set digital-wills
                    { testator: testator }
                    (merge will { is-active: false })
                )
                (unwrap-panic (log-event "WILL_REVOKED" testator "Digital will revoked"))
                (ok true)
            )
            error (err ERR-WILL-NOT-FOUND)
        )
    )
)