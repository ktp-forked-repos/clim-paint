
(in-package :clim-paint)

;;; selection handle
(defclass selection-handle-object ()
  ((paint-object :initarg :paint-object :accessor paint-object)
   (ink :initarg :ink :accessor ink)
   (line-thickness :initarg :line-thickness :accessor line-thickness)
   (filled :initarg :filled :accessor filledp)))

(defgeneric selection-handle-object-p (object)
  (:method ((object t)) nil)
  (:method ((object selection-handle-object)) t)
  (:documentation "Checking for class selection-handle-object"))

(defclass selection-handle-point (selection-handle-object)
  ((point :type point :initarg :point :accessor %point)
   (radius :initarg :radius :accessor radius)))

;;;
;;; selection-handle-point-presentation
(defclass selection-handle-point-presentation (standard-presentation) ())

(define-presentation-type selection-handle-point-presentation ())

(define-presentation-method present (selection-handle-object
                                     (type selection-handle-point) pane
                                     (view clim-paint-view)
                                     &key)
  (multiple-value-bind (x y)
      (point-position (%point selection-handle-object))
    (draw-circle* pane x y (radius selection-handle-object)
                  :ink (ink selection-handle-object)
                  :filled (filledp selection-handle-object)
                  :line-thickness 2)))

;;; selection

(define-clim-paint-command (com-select-object)
    ((presentation t))
  (let ((pane (get-frame-pane *application-frame* 'app)))
    (funcall-presentation-generic-function select-presentation
                                           (type-of (presentation-object presentation))
                                           presentation pane :select)))

(define-gesture-name select-gesture :pointer-button (:middle))

(define-presentation-to-command-translator select-paint-object-translator
    (paint-object com-select-object clim-paint
                  :gesture select-gesture
                  :menu nil
                  :tester ((object)
                           t))
    (object presentation)
  (list presentation))

(define-presentation-to-command-translator select-selection-handle-object-translator
    (selection-handle-object com-select-object clim-paint
                  :gesture select-gesture
                  :menu nil
                  :tester ((object)
                           t))
    (object presentation)
  (list presentation))

(define-presentation-method select-presentation
    ((type paint-object) (record presentation) stream state)
  (let* ((frame *application-frame*)
         (properties-pane (find-pane-named frame 'properties)))
    (case state
      (:select
       (clrhash (selected-object-hash frame))
       (let ((object (presentation-object record)))
         (setf (pane-object properties-pane) object)
         (setf (gethash object (selected-object-hash frame)) t))
       (queue-repaint stream
                      (make-instance 'window-repaint-event
                                     :sheet stream
                                     :region +everywhere+)))
      (:deselect
       (clrhash (selected-object-hash frame))
       (setf (pane-object properties-pane) nil)
       (queue-repaint
        stream
        (make-instance 'window-repaint-event
                       :sheet stream
                       :region +everywhere+))))
    (setf (pane-needs-redisplay properties-pane) t)
    (clim:redisplay-frame-pane frame properties-pane)
    #+nil
    ;; or should we do it like this?
    (queue-repaint properties-pane
                   (make-instance 'window-repaint-event
                                  :sheet properties-pane
                                  :region +everywhere+))))

