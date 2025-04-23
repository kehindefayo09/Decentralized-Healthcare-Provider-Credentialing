;; Facility Privileging Contract
;; Manages approved procedures by institution

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_EXISTS u2)
(define-constant ERR_NOT_FOUND u3)
(define-constant ERR_PROVIDER_NOT_FOUND u4)
(define-constant ERR_FACILITY_NOT_FOUND u5)

;; Privilege status types
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)
(define-constant STATUS_EXPIRED u4)
(define-constant STATUS_PENDING u5)

;; Data structures
(define-map facilities
  { facility-id: principal }
  {
    name: (string-utf8 100),
    facility-type: (string-utf8 50),
    location: (string-utf8 100),
    created-at: uint
  }
)

(define-map privileges
  {
    facility-id: principal,
    provider-id: principal,
    procedure-id: uint
  }
  {
    procedure-name: (string-utf8 100),
    status: uint,
    granted-at: uint,
    expires-at: uint,
    granted-by: principal
  }
)

(define-map facility-procedures
  {
    facility-id: principal,
    provider-id: principal
  }
  { procedure-ids: (list 50 uint) }
)

(define-data-var procedure-counter uint u0)

;; Admin and facility admin principals
(define-data-var admin principal tx-sender)
(define-map facility-admins
  { facility-id: principal }
  { admins: (list 10 principal) }
)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Check if caller is a facility admin
(define-private (is-facility-admin (facility-id principal))
  (let
    ((facility-admin-list (map-get? facility-admins {facility-id: facility-id})))
    (and
      (is-some facility-admin-list)
      (is-some (index-of (get admins (unwrap-panic facility-admin-list)) tx-sender))
    )
  )
)

;; Register a facility (admin only)
(define-public (register-facility
    (facility-id principal)
    (name (string-utf8 100))
    (facility-type (string-utf8 50))
    (location (string-utf8 100))
  )
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? facilities {facility-id: facility-id})) (err ERR_ALREADY_EXISTS))
    (ok (map-set facilities
      {facility-id: facility-id}
      {
        name: name,
        facility-type: facility-type,
        location: location,
        created-at: block-height
      }
    ))
  )
)

;; Grant privilege to a provider (by facility admin)
(define-public (grant-privilege
    (facility-id principal)
    (provider-id principal)
    (procedure-name (string-utf8 100))
    (expires-at uint)
  )
  (let
    (
      (procedure-id (+ (var-get procedure-counter) u1))
      (facility-data (map-get? facilities {facility-id: facility-id}))
      (provider-procedures (default-to {procedure-ids: (list)}
                          (map-get? facility-procedures {facility-id: facility-id, provider-id: provider-id})))
      (updated-procedures (unwrap-panic (as-max-len?
                          (append (get procedure-ids provider-procedures) procedure-id)
                          u50)))
    )
    (asserts! (or (is-admin) (is-facility-admin facility-id)) (err ERR_UNAUTHORIZED))
    (asserts! (is-some facility-data) (err ERR_FACILITY_NOT_FOUND))

    (var-set procedure-counter procedure-id)
    (map-set privileges
      {facility-id: facility-id, provider-id: provider-id, procedure-id: procedure-id}
      {
        procedure-name: procedure-name,
        status: STATUS_ACTIVE,
        granted-at: block-height,
        expires-at: expires-at,
        granted-by: tx-sender
      }
    )
    (map-set facility-procedures
      {facility-id: facility-id, provider-id: provider-id}
      {procedure-ids: updated-procedures}
    )
    (ok procedure-id)
  )
)

;; Update privilege status (by facility admin)
(define-public (update-privilege-status
    (facility-id principal)
    (provider-id principal)
    (procedure-id uint)
    (new-status uint)
  )
  (let
    ((privilege-data (map-get? privileges {facility-id: facility-id, provider-id: provider-id, procedure-id: procedure-id})))
    (asserts! (or (is-admin) (is-facility-admin facility-id)) (err ERR_UNAUTHORIZED))
    (asserts! (is-some privilege-data) (err ERR_NOT_FOUND))
    (asserts! (and (>= new-status STATUS_ACTIVE) (<= new-status STATUS_PENDING)) (err u100))
    (ok (map-set privileges
      {facility-id: facility-id, provider-id: provider-id, procedure-id: procedure-id}
      (merge (unwrap-panic privilege-data)
        {
          status: new-status,
          granted-by: tx-sender
        }
      )
    ))
  )
)

;; Get privilege information
(define-read-only (get-privilege
    (facility-id principal)
    (provider-id principal)
    (procedure-id uint)
  )
  (map-get? privileges {facility-id: facility-id, provider-id: provider-id, procedure-id: procedure-id})
)

;; Get all privileges for a provider at a facility
(define-read-only (get-provider-privileges (facility-id principal) (provider-id principal))
  (map-get? facility-procedures {facility-id: facility-id, provider-id: provider-id})
)

;; Check if privilege is active
(define-read-only (is-privilege-active
    (facility-id principal)
    (provider-id principal)
    (procedure-id uint)
  )
  (let
    ((privilege-data (map-get? privileges {facility-id: facility-id, provider-id: provider-id, procedure-id: procedure-id})))
    (and
      (is-some privilege-data)
      (is-eq (get status (unwrap-panic privilege-data)) STATUS_ACTIVE)
      (> (get expires-at (unwrap-panic privilege-data)) block-height)
    )
  )
)

;; Add a facility admin (by admin or existing facility admin)
(define-public (add-facility-admin (facility-id principal) (new-admin principal))
  (let
    (
      (facility-data (map-get? facilities {facility-id: facility-id}))
      (admin-list (default-to {admins: (list)} (map-get? facility-admins {facility-id: facility-id})))
      (updated-admins (unwrap-panic (as-max-len?
                      (append (get admins admin-list) new-admin)
                      u10)))
    )
    (asserts! (or (is-admin) (is-facility-admin facility-id)) (err ERR_UNAUTHORIZED))
    (asserts! (is-some facility-data) (err ERR_FACILITY_NOT_FOUND))
    (ok (map-set facility-admins
      {facility-id: facility-id}
      {admins: updated-admins}
    ))
  )
)

;; Set new admin (only current admin can do this)
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (var-set admin new-admin))
  )
)
