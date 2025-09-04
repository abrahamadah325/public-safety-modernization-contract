;; SPDX-License-Identifier: MIT
;; Emergency Response And Resource Coordination Smart Contract
;; Part of the Public safety modernization contract project
;;
;; This contract implements emergency response and resource coordination functionality with comprehensive
;; security measures, access controls, and operational features.
;;
;; Author: Jordan Taylor
;; Version: 1.0.0
;; Last Updated: 2025-09-04

;; =============================================================================
;; ERROR CONSTANTS
;; =============================================================================

(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-INVALID-RECIPIENT (err u105))
(define-constant ERR-CONTRACT-PAUSED (err u106))
(define-constant ERR-INVALID-CALLER (err u107))
(define-constant ERR-TRANSFER-FAILED (err u108))
(define-constant ERR-INVALID-PARAMETERS (err u109))
(define-constant ERR-OPERATION-RESTRICTED (err u110))
(define-constant ERR-INSUFFICIENT-PERMISSIONS (err u111))

;; =============================================================================
;; DATA VARIABLES
;; =============================================================================

(define-data-var contract-owner principal tx-sender)
(define-data-var total-supply uint u0)
(define-data-var contract-paused bool false)
(define-data-var admin-count uint u1)
(define-data-var operation-fee uint u1000)
(define-data-var max-supply uint u1000000000000)
(define-data-var min-transfer-amount uint u1)

;; =============================================================================
;; DATA MAPS
;; =============================================================================

(define-map balances principal uint)
(define-map allowances {spender: principal, owner: principal} uint)
(define-map admins principal bool)
(define-map user-metadata principal {joined-at: uint, last-activity: uint, reputation: uint})
(define-map pending-operations uint {initiator: principal, target: principal, amount: uint, operation-type: (string-ascii 32)})
(define-map operation-approvals {operation-id: uint, approver: principal} bool)

;; =============================================================================
;; ACCESS CONTROL FUNCTIONS
;; =============================================================================

(define-private (is-contract-owner (caller principal))
  (is-eq caller (var-get contract-owner))
)

(define-private (is-admin (caller principal))
  (default-to false (map-get? admins caller))
)

(define-private (is-authorized (caller principal))
  (or (is-contract-owner caller) (is-admin caller))
)

(define-private (check-contract-active)
  (ok (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED))
)

(define-private (validate-amount (amount uint))
  (and 
    (> amount u0)
    (>= amount (var-get min-transfer-amount))
  )
)

(define-private (validate-principal (user principal))
  (not (is-eq user tx-sender))
)

;; =============================================================================
;; PUBLIC FUNCTIONS
;; =============================================================================

(define-public (transfer (recipient principal) (amount uint))
  (let (
    (sender tx-sender)
    (sender-balance (get-balance sender))
  )
    (try! (check-contract-active))
    (asserts! (validate-amount amount) ERR-INVALID-AMOUNT)
    (asserts! (validate-principal recipient) ERR-INVALID-RECIPIENT)
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update balances
    (map-set balances sender (- sender-balance amount))
    (map-set balances recipient (+ (get-balance recipient) amount))
    
    ;; Log transfer event
    (print {event: "transfer", from: sender, to: recipient, amount: amount})
    (ok true)
  )
)

(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-UNAUTHORIZED)
    (try! (check-contract-active))
    (asserts! (validate-amount amount) ERR-INVALID-AMOUNT)
    (asserts! (<= (+ (var-get total-supply) amount) (var-get max-supply)) ERR-INVALID-AMOUNT)
    
    ;; Update supply and balance
    (var-set total-supply (+ (var-get total-supply) amount))
    (map-set balances recipient (+ (get-balance recipient) amount))
    
    ;; Log mint event
    (print {event: "mint", recipient: recipient, amount: amount})
    (ok true)
  )
)

(define-public (burn (amount uint))
  (let (
    (sender tx-sender)
    (sender-balance (get-balance sender))
  )
    (try! (check-contract-active))
    (asserts! (validate-amount amount) ERR-INVALID-AMOUNT)
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update supply and balance
    (var-set total-supply (- (var-get total-supply) amount))
    (map-set balances sender (- sender-balance amount))
    
    ;; Log burn event
    (print {event: "burn", from: sender, amount: amount})
    (ok true)
  )
)

;; =============================================================================
;; ADMINISTRATIVE FUNCTIONS
;; =============================================================================

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq new-owner (var-get contract-owner))) ERR-INVALID-PARAMETERS)
    
    (print {event: "owner-change", old-owner: (var-get contract-owner), new-owner: new-owner})
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (pause-contract)
  (begin
    (asserts! (is-authorized tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (var-get contract-paused)) ERR-INVALID-PARAMETERS)
    
    (var-set contract-paused true)
    (print {event: "contract-paused", by: tx-sender})
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-UNAUTHORIZED)
    (asserts! (var-get contract-paused) ERR-INVALID-PARAMETERS)
    
    (var-set contract-paused false)
    (print {event: "contract-unpaused", by: tx-sender})
    (ok true)
  )
)

(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (default-to false (map-get? admins new-admin))) ERR-ALREADY-EXISTS)
    
    (map-set admins new-admin true)
    (var-set admin-count (+ (var-get admin-count) u1))
    (print {event: "admin-added", admin: new-admin, by: tx-sender})
    (ok true)
  )
)

(define-public (remove-admin (admin principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-UNAUTHORIZED)
    (asserts! (default-to false (map-get? admins admin)) ERR-NOT-FOUND)
    (asserts! (> (var-get admin-count) u1) ERR-OPERATION-RESTRICTED)
    
    (map-delete admins admin)
    (var-set admin-count (- (var-get admin-count) u1))
    (print {event: "admin-removed", admin: admin, by: tx-sender})
    (ok true)
  )
)

(define-public (emergency-withdraw (recipient principal))
  (let (
    (contract-balance (stx-get-balance (as-contract tx-sender)))
  )
    (asserts! (is-contract-owner tx-sender) ERR-UNAUTHORIZED)
    (asserts! (var-get contract-paused) ERR-OPERATION-RESTRICTED)
    (asserts! (> contract-balance u0) ERR-INSUFFICIENT-BALANCE)
    
    (print {event: "emergency-withdraw", recipient: recipient, amount: contract-balance})
    (as-contract (stx-transfer? contract-balance tx-sender recipient))
  )
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-balance (owner principal))
  (default-to u0 (map-get? balances owner))
)

(define-read-only (get-total-supply)
  (var-get total-supply)
)

(define-read-only (get-owner)
  (var-get contract-owner)
)

(define-read-only (is-contract-paused)
  (var-get contract-paused)
)

(define-read-only (get-admin-status (user principal))
  (default-to false (map-get? admins user))
)

(define-read-only (get-admin-count)
  (var-get admin-count)
)

(define-read-only (get-operation-fee)
  (var-get operation-fee)
)

(define-read-only (get-max-supply)
  (var-get max-supply)
)

(define-read-only (get-min-transfer-amount)
  (var-get min-transfer-amount)
)

(define-read-only (get-user-metadata (user principal))
  (map-get? user-metadata user)
)

(define-read-only (get-contract-info)
  {
    total-supply: (var-get total-supply),
    max-supply: (var-get max-supply),
    owner: (var-get contract-owner),
    paused: (var-get contract-paused),
    admin-count: (var-get admin-count),
    operation-fee: (var-get operation-fee)
  }
)
