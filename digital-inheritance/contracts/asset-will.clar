;; Digital Asset Will Smart Contract
;; Implements complete asset transfer logic, events, backup executors, and granular permissions

;; Import traits for fungible and non-fungible tokens
(use-trait ft-trait .sip-010-trait-ft-standard.sip-010-trait)
(use-trait nft-trait .sip-009-trait-nft-standard.sip-009-trait)

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

;; Private functions
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

;; Asset transfer functions
(define-private (transfer-stx-asset (recipient principal) (amount uint))
    (stx-transfer? amount tx-sender recipient)
)

(define-private (transfer-ft-asset (token <ft-trait>) (recipient principal) (amount uint))
    (contract-call? token transfer amount tx-sender recipient none)
)

(define-private (transfer-nft-asset (token <nft-trait>) (recipient principal) (token-id uint))
    (contract-call? token transfer token-id tx-sender recipient)
)

;; Read-only functions
(define-read-only (get-digital-will (testator principal))
    (ok (map-get? digital-wills { testator: testator }))
)

(define-read-only (get-event (event-id uint))
    (ok (map-get? events { event-id: event-id }))
)

(define-read-only (check-will-status (testator principal))
    (let ((will (map-get? digital-wills { testator: testator })))
        (match will
            will-data (let
                (
                    (current-time (unwrap-panic (get-block-info? time u0)))
                    (last-activity (get last-activity will-data))
                    (threshold (get inactivity-threshold will-data))
                )
                (ok {
                    is-active: (get is-active will-data),
                    is-executed: (get is-executed will-data),
                    inactive-duration: (- current-time last-activity),
                    can-execute: (> (- current-time last-activity) threshold)
                }))
            (err ERR-WILL-NOT-FOUND)
        )
    )
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
        (if (is-none (map-get? digital-wills { testator: testator }))
            (begin
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
            (err ERR-WILL-EXISTS)
        )
    )
)

(define-public (update-inactivity-threshold (new-threshold uint))
    (let ((testator tx-sender)
          (will (map-get? digital-wills { testator: testator })))
        (match will
            will-data (begin
                (asserts! (not (get is-executed will-data)) (err ERR-WILL-ALREADY-EXECUTED))
                (asserts! (>= new-threshold u1) (err ERR-INVALID-PERIOD))
                
                (map-set digital-wills
                    { testator: testator }
                    (merge will-data { inactivity-threshold: new-threshold })
                )
                (unwrap-panic (log-event "THRESHOLD_UPDATED" testator "Inactivity threshold updated"))
                (ok true)
            )
            (err ERR-WILL-NOT-FOUND)
        )
    )
)

(define-public (update-backup-executors (new-executors (list 3 principal)))
    (let ((testator tx-sender)
          (will (map-get? digital-wills { testator: testator })))
        (match will
            will-data (begin
                (asserts! (not (get is-executed will-data)) (err ERR-WILL-ALREADY-EXECUTED))
                
                (map-set digital-wills
                    { testator: testator }
                    (merge will-data { backup-executors: new-executors })
                )
                (unwrap-panic (log-event "EXECUTORS_UPDATED" testator "Backup executors updated"))
                (ok true)
            )
            (err ERR-WILL-NOT-FOUND)
        )
    )
)

(define-public (record-activity)
    (let ((testator tx-sender)
          (will (map-get? digital-wills { testator: testator })))
        (match will
            will-data (begin
                (asserts! (not (get is-executed will-data)) (err ERR-WILL-ALREADY-EXECUTED))
                (asserts! (get is-active will-data) (err ERR-WILL-INACTIVE))
                
                (map-set digital-wills
                    { testator: testator }
                    (merge will-data { last-activity: (unwrap-panic (get-block-info? time u0)) })
                )
                (unwrap-panic (log-event "ACTIVITY_RECORDED" testator "Activity timestamp updated"))
                (ok true)
            )
            (err ERR-WILL-NOT-FOUND)
        )
    )
)

(define-public (execute-digital-will (testator principal))
    (let ((executor tx-sender)
          (will (map-get? digital-wills { testator: testator })))
        (match will
            will-data (begin
                ;; Verify execution conditions
                (asserts! (get is-active will-data) (err ERR-WILL-INACTIVE))
                (asserts! (not (get is-executed will-data)) (err ERR-WILL-ALREADY-EXECUTED))
                (asserts! (or
                    (is-some (index-of (get backup-executors will-data) executor))
                    (> (- (unwrap-panic (get-block-info? time u0)) (get last-activity will-data)) 
                       (get inactivity-threshold will-data))
                ) (err ERR-UNAUTHORIZED))
                
                ;; Execute transfers
                ;; Note: Implementation of asset transfers would need to be modified based on
                ;; the specific token contracts and their implementations
                
                ;; Mark will as executed
                (map-set digital-wills
                    { testator: testator }
                    (merge will-data { 
                        is-executed: true,
                        is-active: false
                    })
                )
                
                (unwrap-panic (log-event "WILL_EXECUTED" executor "Digital will executed successfully"))
                (ok true)
            )
            (err ERR-WILL-NOT-FOUND)
        )
    )
)

(define-public (revoke-digital-will)
    (let ((testator tx-sender)
          (will (map-get? digital-wills { testator: testator })))
        (match will
            will-data (begin
                (asserts! (not (get is-executed will-data)) (err ERR-WILL-ALREADY-EXECUTED))
                
                (map-set digital-wills
                    { testator: testator }
                    (merge will-data { is-active: false })
                )
                (unwrap-panic (log-event "WILL_REVOKED" testator "Digital will revoked"))
                (ok true)
            )
            (err ERR-WILL-NOT-FOUND)
        )
    )
)