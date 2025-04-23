;; Qualification Verification Contract
;; Validates medical degrees and training

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_EXISTS u2)
(define-constant ERR_NOT_FOUND u3)
(define-constant ERR_PROVIDER_NOT_FOUND u4)

;; Data structures
(define-map qualifications
  {
    provider-id: principal,
    qualification-id: uint
  }
  {
    degree: (string-utf8 100),
    institution: (string-utf8 100),
    year: uint,
    verified: bool,
    verifier: (optional principal),
    verification-date: (optional uint)
  }
)

(define-data-var qualification-counter uint u0)
(define-map provider-qualifications
  { provider-id: principal }
  { qualification-ids: (list 20 uint) }
)

;; Admin and verifier principals
(define-data-var admin principal tx-sender)
(define-map verifiers principal bool)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Check if caller is a verifier
(define-private (is-verifier)
  (default-to false (map-get? verifiers tx-sender))
)

;; Add a qualification (by provider)
(define-public (add-qualification
    (degree (string-utf8 100))
    (institution (string-utf8 100))
    (year uint)
  )
  (let
    (
      (qualification-id (+ (var-get qualification-counter) u1))
      (provider-quals (default-to {qualification-ids: (list)}
                      (map-get? provider-qualifications {provider-id: tx-sender})))
      (updated-quals (unwrap-panic (as-max-len?
                      (append (get qualification-ids provider-quals) qualification-id)
                      u20)))
    )
    (var-set qualification-counter qualification-id)
    (map-set qualifications
      {provider-id: tx-sender, qualification-id: qualification-id}
      {
        degree: degree,
        institution: institution,
        year: year,
        verified: false,
        verifier: none,
        verification-date: none
      }
    )
    (map-set provider-qualifications
      {provider-id: tx-sender}
      {qualification-ids: updated-quals}
    )
    (ok qualification-id)
  )
)

;; Verify a qualification (by verifier)
(define-public (verify-qualification (provider-id principal) (qualification-id uint))
  (let
    ((qualification (map-get? qualifications {provider-id: provider-id, qualification-id: qualification-id})))
    (asserts! (or (is-admin) (is-verifier)) (err ERR_UNAUTHORIZED))
    (asserts! (is-some qualification) (err ERR_NOT_FOUND))
    (ok (map-set qualifications
      {provider-id: provider-id, qualification-id: qualification-id}
      (merge (unwrap-panic qualification)
        {
          verified: true,
          verifier: (some tx-sender),
          verification-date: (some block-height)
        }
      )
    ))
  )
)

;; Get qualification details
(define-read-only (get-qualification (provider-id principal) (qualification-id uint))
  (map-get? qualifications {provider-id: provider-id, qualification-id: qualification-id})
)

;; Get all qualifications for a provider
(define-read-only (get-provider-qualifications (provider-id principal))
  (map-get? provider-qualifications {provider-id: provider-id})
)

;; Add a verifier (admin only)
(define-public (add-verifier (verifier-id principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (map-set verifiers verifier-id true))
  )
)

;; Remove a verifier (admin only)
(define-public (remove-verifier (verifier-id principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (map-set verifiers verifier-id false))
  )
)

;; Set new admin (only current admin can do this)
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (var-set admin new-admin))
  )
)
