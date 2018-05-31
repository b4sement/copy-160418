#lang racket
(require "auto.rkt" "inout.rkt" "cons.rkt")
(require plot racket/hash)
(plot-new-window? #t)

(provide (all-defined-out))


;; POPULATION
(define (build-random-population n)
  (build-vector n (lambda (_) (make-random-automaton))))

(define (match-population population)
  (for
      ([i (in-range 0 (- (vector-length population) 1) 2)])
    (define auto1 (vector-ref population i))
    (define auto2 (vector-ref population (+ i 1)))
    (define-values (a1 a2)
      (interact auto1 auto2))
    (vector-set! population i a1)
    (vector-set! population (+ i 1) a2))
  population)

(define (population-payoffs population)
  (for/list
      ([auto population])
    (automaton-payoff auto)))

(define (sum l)
  (apply + l))

(define (payoff->fitness population)
  (define payoffs (population-payoffs population))
  (define total (sum payoffs))
  (for/list ([p (in-list payoffs)])
    (/ p total)))

(define (accumulate probabilities)
  (let accumulate-helper
      ([remainders probabilities] [so-far #i0.0])
    (cond
      [(empty? remainders) '()]
      [else (define nxt (+ so-far (first remainders)))
            (cons nxt (accumulate-helper (rest remainders) nxt))])))

;; choose auto depending on fitness
(define (randomise-auto probabilities speed)
  (define accumulated-fitness-vector (accumulate probabilities))
  (for/list ([n (in-range speed)])
    (define r (random))
    (for/last ([p (in-naturals)]
               [% (in-list accumulated-fitness-vector)]
               #:final (< r %)) p)))

(define (shuffle-vector vec)
  (define lst (vector->list vec))
  (define l2 (shuffle lst))
  (list->vector l2))

(define (regenerate population rate)
  (define probabilities (payoff->fitness population))
  (define substitutes (randomise-auto probabilities rate))
  (for ([i (in-range rate)]
        [auto (in-list substitutes)])
    (vector-set! population i
                 (vector-ref population auto)))
  (shuffle-vector population))

(define (population-reset population)
  (for ([auto population]
        [i (in-naturals)])
    (vector-set! population i (reset auto))))

(define (average lst)
  (exact->inexact (/ (sum lst) (length lst))))

;; PLOT
(define (population-mean->lines data)
  (define coors
    (for/list ([d (in-list data)]
               [n (in-naturals)])
      (list n d)))
  (lines coors))

(define (compound d r)
  (foldl (lambda (n a) (+ a (expt d n))) 1 (build-list (- r 1) add1)))

(define (plot-mean data delta rounds pic tit)
  (define h (* 8 (compound delta rounds)))
  (define m (* 5 (compound delta rounds)))
  (define l (* 2 (compound delta rounds)))
  (define h-line
    (function (lambda (x) h) #:color "red"))
  (define m-line
    (function (lambda (x) m) #:color "green"))
  (define l-line
    (function (lambda (x) l) #:color "blue"))
  (plot (list h-line m-line l-line
              (population-mean->lines data))
        #:y-min 0 #:y-max (+ 5 h) #:width 1200 #:height 800
        #:out-file pic #:title tit))

(define (plot-mean-p data delta rounds)
  (define h (* 8 (compound delta rounds)))
  (define m (* 5 (compound delta rounds)))
  (define l (* 2 (compound delta rounds)))
  (define h-line
    (function (lambda (x) h) #:color "red"))
  (define m-line
    (function (lambda (x) m) #:color "green"))
  (define l-line
    (function (lambda (x) l) #:color "blue"))
  (plot (list h-line m-line l-line
              (population-mean->lines data))
        #:y-min 0 #:y-max (+ 5 h) #:width 1200 #:height 800))

;; SCAN
(define (scan population)
  (define p (vector->list population))
  (foldl
   (lambda (au h)
     (hash-update h au add1 0))
   (hash)
   p))

(define (scan-f population)
  (define p (vector->list population))
  (foldl
   (lambda (au h)
     (hash-update h (flatten-automaton au) add1 0))
   (hash)
   p))

(define (sort-population p)
 (sort (hash->list (scan-f (vector-map reset p)))
       > #:key cdr))

;; MUTATE
(define (mutate-population population rate)
  (for ([i (in-range rate)])

    (define auto (vector-ref population i))
    (vector-set! population i (mutate auto))))

;; MAIN
(define (evolve population cycles speed mutation mean-file rank-file p-file sim-id)
  (cond
    [(zero? cycles) (out-population sim-id (scan-f population) p-file)]
    [else
     (and (zero? (modulo cycles 100)) (print (number->string cycles)))
     (define p2 (match-population population))
     (define pp (population-payoffs p2))
     (define p3 (regenerate p2 speed))
     (define p4 (vector-map reset p3))
     (and (zero? (modulo cycles 100)) (out-rank cycles (scan-f p4) rank-file))
     (mutate-population p4 mutation)
     (out-data mean-file (list (list (average pp))))
     (evolve p4 (- cycles 1)
             speed mutation mean-file rank-file p-file sim-id)]))

(define (evolve-p population cycles speed mutation)
  (cond
    [(zero? cycles) (list population)]
    [else
     (define p2 (match-population population))
     (define pp (population-payoffs p2))
     (define p3 (regenerate p2 speed))
     (define auto (vector-ref p3 0))
;;     (and (zero? (modulo cycles 100)) (out-rank cycles (scan p3) rank-file))
     (mutate-population p3 mutation)    
;;     (out-data mean-file (list (list (average pp))))
     (cons (average pp)
           (evolve-p (vector-map reset p3) (- cycles 1)
                   speed mutation))]))

(define (gen-name location id name)
  (format "~a~a~a~a"
	(if (= location 1) OUTLABstr "")
          DELTAstr (number->string id) name))

(define (gen-pic-title)
  (format "ID = ~s, N = ~s, s = ~s, r = ~s, d = ~s, m = ~s" SIM-ID N SPEED ROUNDS DELTA MUTATION))

(define (main)
  (collect-garbage)
  (define POPU
(gen-name LOCATION SIM-ID "p.txt"))
	(define p-POPU (gen-name LOCATION (- SIM-ID 1) "p.txt"))
  (define POPULATION
    (if (= SIM-ID 1)
        (build-random-population N)
        (resurrect-p (csvfile->list p-POPU))))
  (define MEAN (gen-name LOCATION SIM-ID "mean"))
  (define RANK (gen-name LOCATION SIM-ID "rank"))
  (time (evolve POPULATION CYCLES SPEED MUTATION MEAN RANK POPU SIM-ID))
  (define DATA (csvfile->list MEAN))
  (define PIC (gen-name LOCATION SIM-ID "pic.png"))
  (define TIT (gen-pic-title))
  (plot-mean (input->numbers DATA) DELTA ROUNDS PIC TIT))