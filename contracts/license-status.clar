;; License Status Contract
;; Tracks active/suspended status of professionals

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_EXISTS u2)
(define-constant ERR_NOT_FOUND u3)
(define-constant ERR_PROVIDER_NOT_FOUND u4)

;; License status types
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)
(define-constant STATUS_EXPIRED u4)
(define-constant STATUS_PENDING u5)

;; Data structures
(define-map licenses
  { provider-id: principal }
  {
    license-number: (string-utf8 50),
    license-type: (string-utf8 50),
    issuing-authority: (string-utf8 100),
    status: uint,
    issue-date: uint,
    expiry-date: uint,
    last-updated: uint,
    updated-by: principal
  }
)

;; Admin and authority principals
(define-data-var admin principal tx-sender)
(define-map authorities principal bool)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Check if caller is an authority
(define-private (is-authority)
  (default-to false (map-get? authorities tx-sender))
)

;; Register a license (by authority)
(define-public (register-license
    (provider-id principal)
    (license-number (string-utf8 50))
    (license-type (string-utf8 50))
    (issuing-authority (string-utf8 100))
    (issue-date uint)
    (expiry-date uint)
  )
  (begin
    (asserts! (or (is-admin) (is-authority)) (err ERR_UNAUTHORIZED))
    (ok (map-set licenses
      {provider-id: provider-id}
      {
        license-number: license-number,
        license-type: license-type,
        issuing-authority: issuing-authority,
        status: STATUS_ACTIVE,
        issue-date: issue-date,
        expiry-date: expiry-date,
        last-updated: block-height,
        updated-by: tx-sender
      }
    ))
  )
)

;; Update license status (by authority)
(define-public (update-license-status
    (provider-id principal)
    (new-status uint)
  )
  (let
    ((license-data (map-get? licenses {provider-id: provider-id})))
    (asserts! (or (is-admin) (is-authority)) (err ERR_UNAUTHORIZED))
    (asserts! (is-some license-data) (err ERR_NOT_FOUND))
    (asserts! (and (>= new-status STATUS_ACTIVE) (<= new-status STATUS_PENDING)) (err u100))
    (ok (map-set licenses
      {provider-id: provider-id}
      (merge (unwrap-panic license-data)
        {
          status: new-status,
          last-updated: block-height,
          updated-by: tx-sender
        }
      )
    ))
  )
)

;; Update license expiry (by authority)
(define-public (update-license-expiry
    (provider-id principal)
    (new-expiry-date uint)
  )
  (let
    ((license-data (map-get? licenses {provider-id: provider-id})))
    (asserts! (or (is-admin) (is-authority)) (err ERR_UNAUTHORIZED))
    (asserts! (is-some license-data) (err ERR_NOT_FOUND))
    (ok (map-set licenses
      {provider-id: provider-id}
      (merge (unwrap-panic license-data)
        {
          expiry-date: new-expiry-date,
          last-updated: block-height,
          updated-by: tx-sender
        }
      )
    ))
  )
)

;; Get license information
(define-read-only (get-license (provider-id principal))
  (map-get? licenses {provider-id: provider-id})
)

;; Check if license is active
(define-read-only (is-license-active (provider-id principal))
  (let
    ((license-data (map-get? licenses {provider-id: provider-id})))
    (and
      (is-some license-data)
      (is-eq (get status (unwrap-panic license-data)) STATUS_ACTIVE)
      (> (get expiry-date (unwrap-panic license-data)) block-height)
    )
  )
)

;; Add an authority (admin only)
(define-public (add-authority (authority-id principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (map-set authorities authority-id true))
  )
)

;; Remove an authority (admin only)
(define-public (remove-authority (authority-id principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (map-set authorities authority-id false))
  )
)

;; Set new admin (only current admin can do this)
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (var-set admin new-admin))
  )
)
