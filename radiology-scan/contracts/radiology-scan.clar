;; RadiologyScan - Radiology Imaging and Reporting System
;; Version: 1.0.0

(define-constant ERR_NOT_AUTHORIZED (err u400))
(define-constant ERR_STUDY_NOT_FOUND (err u401))
(define-constant ERR_INVALID_RADIOLOGIST (err u402))
(define-constant ERR_REPORT_EXISTS (err u403))
(define-constant ERR_INVALID_STUDY_TYPE (err u404))

(define-map imaging-studies
  { study-id: uint }
  {
    patient-id: principal,
    ordering-physician: principal,
    study-type: (string-ascii 50),
    body-part: (string-ascii 100),
    study-date: uint,
    modality: (string-ascii 20),
    contrast-used: bool,
    clinical-indication: (string-ascii 300),
    assigned-radiologist: principal,
    study-status: (string-ascii 30),
    priority-level: (string-ascii 20)
  }
)

(define-map radiology-reports
  { study-id: uint }
  {
    radiologist-id: principal,
    report-date: uint,
    clinical-history: (string-ascii 300),
    technique: (string-ascii 200),
    findings: (string-ascii 800),
    impression: (string-ascii 400),
    recommendations: (string-ascii 300),
    report-status: (string-ascii 30),
    dictation-timestamp: uint,
    verification-timestamp: uint
  }
)

(define-map radiologist-credentials
  { radiologist-id: principal }
  {
    full-name: (string-ascii 100),
    medical-license: (string-ascii 50),
    board-certification: (string-ascii 100),
    subspecialty: (string-ascii 100),
    years-experience: uint,
    studies-read: uint,
    accuracy-score: uint,
    is-active: bool
  }
)

(define-data-var next-study-id uint u1)
(define-data-var next-annotation-id uint u1)
(define-constant contract-owner tx-sender)

(define-public (register-radiologist
  (radiologist-id principal)
  (full-name (string-ascii 100))
  (medical-license (string-ascii 50))
  (board-certification (string-ascii 100))
  (subspecialty (string-ascii 100))
  (years-experience uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR_NOT_AUTHORIZED)
    (map-set radiologist-credentials
      { radiologist-id: radiologist-id }
      {
        full-name: full-name,
        medical-license: medical-license,
        board-certification: board-certification,
        subspecialty: subspecialty,
        years-experience: years-experience,
        studies-read: u0,
        accuracy-score: u92,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (order-imaging-study
  (patient-id principal)
  (study-type (string-ascii 50))
  (body-part (string-ascii 100))
  (modality (string-ascii 20))
  (contrast-used bool)
  (clinical-indication (string-ascii 300))
  (assigned-radiologist principal)
  (priority-level (string-ascii 20)))
  (let ((study-id (var-get next-study-id))
        (radiologist-data (unwrap! (map-get? radiologist-credentials { radiologist-id: assigned-radiologist }) ERR_INVALID_RADIOLOGIST)))
    (asserts! (get is-active radiologist-data) ERR_INVALID_RADIOLOGIST)
    (map-set imaging-studies
      { study-id: study-id }
      {
        patient-id: patient-id,
        ordering-physician: tx-sender,
        study-type: study-type,
        body-part: body-part,
        study-date: stacks-block-height,
        modality: modality,
        contrast-used: contrast-used,
        clinical-indication: clinical-indication,
        assigned-radiologist: assigned-radiologist,
        study-status: "scheduled",
        priority-level: priority-level
      }
    )
    (var-set next-study-id (+ study-id u1))
    (ok study-id)
  )
)

(define-public (update-study-status
  (study-id uint)
  (new-status (string-ascii 30)))
  (let ((study-data (unwrap! (map-get? imaging-studies { study-id: study-id }) ERR_STUDY_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get assigned-radiologist study-data)) ERR_NOT_AUTHORIZED)
    (map-set imaging-studies
      { study-id: study-id }
      (merge study-data { study-status: new-status })
    )
    (ok true)
  )
)

(define-public (submit-radiology-report
  (study-id uint)
  (clinical-history (string-ascii 300))
  (technique (string-ascii 200))
  (findings (string-ascii 800))
  (impression (string-ascii 400))
  (recommendations (string-ascii 300)))
  (let ((study-data (unwrap! (map-get? imaging-studies { study-id: study-id }) ERR_STUDY_NOT_FOUND))
        (existing-report (map-get? radiology-reports { study-id: study-id }))
        (radiologist-data (unwrap! (map-get? radiologist-credentials { radiologist-id: tx-sender }) ERR_INVALID_RADIOLOGIST)))
    (asserts! (is-eq tx-sender (get assigned-radiologist study-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-none existing-report) ERR_REPORT_EXISTS)
    (map-set radiology-reports
      { study-id: study-id }
      {
        radiologist-id: tx-sender,
        report-date: stacks-block-height,
        clinical-history: clinical-history,
        technique: technique,
        findings: findings,
        impression: impression,
        recommendations: recommendations,
        report-status: "preliminary",
        dictation-timestamp: stacks-block-height,
        verification-timestamp: u0
      }
    )
    (map-set imaging-studies
      { study-id: study-id }
      (merge study-data { study-status: "reported" })
    )
    (map-set radiologist-credentials
      { radiologist-id: tx-sender }
      (merge radiologist-data { studies-read: (+ (get studies-read radiologist-data) u1) })
    )
    (ok true)
  )
)

(define-public (verify-report (study-id uint))
  (let ((report-data (unwrap! (map-get? radiology-reports { study-id: study-id }) ERR_STUDY_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get radiologist-id report-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get report-status report-data) "preliminary") ERR_NOT_AUTHORIZED)
    (map-set radiology-reports
      { study-id: study-id }
      (merge report-data {
        report-status: "final",
        verification-timestamp: stacks-block-height
      })
    )
    (ok true)
  )
)

(define-map image-annotations
  { study-id: uint, annotation-id: uint }
  {
    radiologist-id: principal,
    annotation-type: (string-ascii 50),
    coordinates: (string-ascii 100),
    measurement-value: uint,
    measurement-unit: (string-ascii 20),
    annotation-text: (string-ascii 200),
    confidence-level: uint,
    annotation-date: uint
  }
)

(define-map critical-findings
  { study-id: uint }
  {
    finding-type: (string-ascii 100),
    severity-level: (string-ascii 20),
    notification-sent: bool,
    notification-timestamp: uint,
    acknowledged-by: principal,
    acknowledgment-timestamp: uint,
    follow-up-required: bool
  }
)

(define-map peer-reviews
  { study-id: uint, reviewer-id: principal }
  {
    review-type: (string-ascii 30),
    review-date: uint,
    agreement-level: (string-ascii 30),
    discrepancy-notes: (string-ascii 400),
    learning-points: (string-ascii 300),
    reviewer-rating: uint
  }
)

(define-public (add-image-annotation
  (study-id uint)
  (annotation-type (string-ascii 50))
  (coordinates (string-ascii 100))
  (measurement-value uint)
  (measurement-unit (string-ascii 20))
  (annotation-text (string-ascii 200))
  (confidence-level uint))
  (let ((study-data (unwrap! (map-get? imaging-studies { study-id: study-id }) ERR_STUDY_NOT_FOUND))
        (annotation-id (var-get next-annotation-id)))
    (asserts! (is-eq tx-sender (get assigned-radiologist study-data)) ERR_NOT_AUTHORIZED)
    (map-set image-annotations
      { study-id: study-id, annotation-id: annotation-id }
      {
        radiologist-id: tx-sender,
        annotation-type: annotation-type,
        coordinates: coordinates,
        measurement-value: measurement-value,
        measurement-unit: measurement-unit,
        annotation-text: annotation-text,
        confidence-level: confidence-level,
        annotation-date: stacks-block-height
      }
    )
    (var-set next-annotation-id (+ annotation-id u1))
    (ok annotation-id)
  )
)

(define-public (flag-critical-finding
  (study-id uint)
  (finding-type (string-ascii 100))
  (severity-level (string-ascii 20))
  (follow-up-required bool))
  (let ((study-data (unwrap! (map-get? imaging-studies { study-id: study-id }) ERR_STUDY_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get assigned-radiologist study-data)) ERR_NOT_AUTHORIZED)
    (map-set critical-findings
      { study-id: study-id }
      {
        finding-type: finding-type,
        severity-level: severity-level,
        notification-sent: true,
        notification-timestamp: stacks-block-height,
        acknowledged-by: (get ordering-physician study-data),
        acknowledgment-timestamp: u0,
        follow-up-required: follow-up-required
      }
    )
    (ok true)
  )
)

(define-public (acknowledge-critical-finding (study-id uint))
  (let ((critical-data (unwrap! (map-get? critical-findings { study-id: study-id }) ERR_STUDY_NOT_FOUND))
        (study-data (unwrap! (map-get? imaging-studies { study-id: study-id }) ERR_STUDY_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get ordering-physician study-data)) ERR_NOT_AUTHORIZED)
    (map-set critical-findings
      { study-id: study-id }
      (merge critical-data { acknowledgment-timestamp: stacks-block-height })
    )
    (ok true)
  )
)

(define-public (conduct-peer-review
  (study-id uint)
  (review-type (string-ascii 30))
  (agreement-level (string-ascii 30))
  (discrepancy-notes (string-ascii 400))
  (learning-points (string-ascii 300))
  (reviewer-rating uint))
  (let ((study-data (unwrap! (map-get? imaging-studies { study-id: study-id }) ERR_STUDY_NOT_FOUND)))
    (asserts! (is-some (map-get? radiologist-credentials { radiologist-id: tx-sender })) ERR_INVALID_RADIOLOGIST)
    (asserts! (not (is-eq tx-sender (get assigned-radiologist study-data))) ERR_NOT_AUTHORIZED)
    (map-set peer-reviews
      { study-id: study-id, reviewer-id: tx-sender }
      {
        review-type: review-type,
        review-date: stacks-block-height,
        agreement-level: agreement-level,
        discrepancy-notes: discrepancy-notes,
        learning-points: learning-points,
        reviewer-rating: reviewer-rating
      }
    )
    (ok true)
  )
)

(define-read-only (get-imaging-study (study-id uint))
  (map-get? imaging-studies { study-id: study-id })
)

(define-read-only (get-radiology-report (study-id uint))
  (map-get? radiology-reports { study-id: study-id })
)

(define-read-only (get-radiologist-credentials (radiologist-id principal))
  (map-get? radiologist-credentials { radiologist-id: radiologist-id })
)

(define-read-only (get-image-annotation (study-id uint) (annotation-id uint))
  (map-get? image-annotations { study-id: study-id, annotation-id: annotation-id })
)

(define-read-only (get-critical-finding (study-id uint))
  (map-get? critical-findings { study-id: study-id })
)

(define-read-only (get-peer-review (study-id uint) (reviewer-id principal))
  (map-get? peer-reviews { study-id: study-id, reviewer-id: reviewer-id })
)

(define-read-only (get-next-study-id)
  (var-get next-study-id)
)

(define-read-only (get-next-annotation-id)
  (var-get next-annotation-id)
)