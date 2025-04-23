;; Provider Identity Contract
;; Manages healthcare practitioner identities

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_REGISTERED u2)
(define-constant ERR_NOT_FOUND u3)

;; Data structures
(define-map providers
  { provider-id: principal }
  {
    name: (string-utf8 100),
    specialty: (string-utf8 100),
    contact: (string-utf8 100),
    created-at: uint,
    updated-at: uint
  }
)

;; Admin principal
(define-data-var admin principal tx-sender)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a new provider
(define-public (register-provider
    (name (string-utf8 100))
    (specialty (string-utf8 100))
    (contact (string-utf8 100))
  )
  (let
    ((provider-exists (map-get? providers {provider-id: tx-sender})))
    (asserts! (is-none provider-exists) (err ERR_ALREADY_REGISTERED))
    (ok (map-set providers
      {provider-id: tx-sender}
      {
        name: name,
        specialty: specialty,
        contact: contact,
        created-at: block-height,
        updated-at: block-height
      }
    ))
  )
)

;; Update provider information
(define-public (update-provider
    (name (string-utf8 100))
    (specialty (string-utf8 100))
    (contact (string-utf8 100))
  )
  (let
    ((provider-data (map-get? providers {provider-id: tx-sender})))
    (asserts! (is-some provider-data) (err ERR_NOT_FOUND))
    (ok (map-set providers
      {provider-id: tx-sender}
      {
        name: name,
        specialty: specialty,
        contact: contact,
        created-at: (get created-at (unwrap-panic provider-data)),
        updated-at: block-height
      }
    ))
  )
)

;; Get provider information
(define-read-only (get-provider (provider-id principal))
  (map-get? providers {provider-id: provider-id})
)

;; Check if provider exists
(define-read-only (provider-exists (provider-id principal))
  (is-some (map-get? providers {provider-id: provider-id}))
)

;; Set new admin (only current admin can do this)
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (var-set admin new-admin))
  )
)
