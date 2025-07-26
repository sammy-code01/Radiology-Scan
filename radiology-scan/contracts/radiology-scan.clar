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
