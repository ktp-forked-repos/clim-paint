
(in-package :clim-paint)

(defun square (x)
  (* x x))

(defun cube (x)
  (* x x x))

;;;
;;; lines
(defun point-line-distance (test-point line-point-1 line-point-2)
  (multiple-value-bind (x1 y1)
      (point-position line-point-1)
    (multiple-value-bind (x2 y2)
        (point-position line-point-2)
      (multiple-value-bind (x0 y0)
          (point-position test-point)
        (/ (abs (+ (* (- y2 y1) x0)
                   (* x2 y1)
                   (- (+ (* (- x2 x1) y0)
                         (* y2 x1)))))
           (sqrt (+ (square (- y2 y1))
                    (square (- x2 x1)))))))))

(defun line-point-between-p (test-point line-point-1 line-point-2
                             &key (line-fuzz 7))
  (let ((distance (point-line-distance test-point line-point-1 line-point-2)))
    (values (< distance line-fuzz)
            distance)))

;;;
;;; bezier curves
(defun 1d-parametric-bezier-curve (tee p0 p1 p2 p3)
  (+ (* (cube (- 1 tee)) p0)
     (* 3 tee (square (- 1 tee)) p1)
     (* 3 (square tee) (- 1 tee) p2)
     (* (cube tee) p3)))

(defun 2d-parametric-bezier-curve (tee p0 p1 p2 p3)
  (multiple-value-bind (p0x p0y)
      (point-position p0)
    (multiple-value-bind (p1x p1y)
        (point-position p1)
      (multiple-value-bind (p2x p2y)
          (point-position p2)
        (multiple-value-bind (p3x p3y)
            (point-position p3)
          (values (1d-parametric-bezier-curve tee p0x p1x p2x p3x)
                  (1d-parametric-bezier-curve tee p0y p1y p2y p3y)))))))

(defun squared-distance-to-parametric-bezier-curve (point tee p0 p1 p2 p3)
  "Returns the square of the distance of POINT to the point on the
bezier curved described by control points P0, P1, P2, P3, and
evaluated at tee where t is in [0,1]."
  (multiple-value-bind (x y)
      (point-position point)
    (multiple-value-bind (bx by)
        (2d-parametric-bezier-curve tee p0 p1 p2 p3)
      (values (+ (square (- bx x))
                 (square (- by y)))
              bx by))))

(defun rough-closest-point-on-bezier-curve (point p0 p1 p2 p3 &key (steps 100))
  (let ((candidates
         (mapcar (lambda (x)
                   (cons x (squared-distance-to-parametric-bezier-curve point x p0 p1 p2 p3)))
                 (loop for i from 0 to steps collect (float (/ i steps))))))
    (car (sort candidates #'< :key #'cdr))))

(defun find-closest-point-on-bezier-curve (point p0 p1 p2 p3 &key (steps 100))
  (multiple-value-bind (val0 x0 y0)
      (squared-distance-to-parametric-bezier-curve
       point 0 p0 p1 p2 p3)
    (multiple-value-bind (val1 x1 y1)
      (squared-distance-to-parametric-bezier-curve
       point 1 p0 p1 p2 p3)
      (let ((guess (car (rough-closest-point-on-bezier-curve
                         point p0 p1 p2 p3 :steps steps))))
        (let ((min-guess (max (- guess (float (/ steps))) 0))
              (max-guess (min (+ guess (float (/ steps))) 1)))
          (multiple-value-bind (tee guess-val)
              (refine-guess min-guess max-guess point p0 p1 p2 p3)
            (cond
              ((<= guess-val (min val0 val1))
               (multiple-value-call #'make-point
                 (2d-parametric-bezier-curve tee p0 p1 p2 p3)))
              ((<= val0 val1)
               (make-point x0 y0))
              (t
               (make-point x1 y1)))))))))

(defun refine-guess (left-guess right-guess point p0 p1 p2 p3 &key (epsilon 0.001))
    (let ((mid-guess (/ (+ left-guess right-guess) 2)))
    (let ((left-value (squared-distance-to-parametric-bezier-curve point left-guess p0 p1 p2 p3))
          (mid-value (squared-distance-to-parametric-bezier-curve point mid-guess p0 p1 p2 p3))
          (right-value (squared-distance-to-parametric-bezier-curve point right-guess p0 p1 p2 p3)))
      (if (< (- right-guess left-guess) epsilon)
          (cond ((<= mid-value (min left-value right-value))
                 (values mid-guess mid-value))
                ((<= left-value right-value)
                 (values left-guess left-value))
                (t (values right-guess right-value)))
          (if (< (abs (- left-value mid-value))
                 (abs (- right-value mid-value)))
              (refine-guess left-guess mid-guess point p0 p1 p2 p3)
              (refine-guess mid-guess right-guess point p0 p1 p2 p3))))))

(defun midpoint (point-1 point-2)
  (multiple-value-bind (x1 y1)
      (point-position point-1)
    (multiple-value-bind (x2 y2)
        (point-position point-2)
      (make-point (/ (+ x1 x2) 2)
                  (/ (+ y1 y2) 2)))))

(defun add-points (point-1 point-2)
  (multiple-value-bind (x1 y1)
      (point-position point-1)
    (multiple-value-bind (x2 y2)
        (point-position point-2)
      (make-point (+ x1 x2)
                  (+ y1 y2)))))
