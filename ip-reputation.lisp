#!/usr/bin/env -S cl-launch -E main --lisp 'sbcl' --wrap 'SBCL_OPTIONS="--noinform"'


(eval-when (:compile-toplevel :load-toplevel :execute)
  (progn
    (ql:quickload '(uiop sb-bsd-sockets lparallel))
    (setf *debugger-hook* (lambda (condition oldhook)
                            (declare (ignore oldhook))
                            (format *error-output* "Caught fatal interrupt...")
                            (finish-output *error-output*)
                            (sb-ext:quit)))))

(defun main (argv)
  (defvar *apikey* (sb-posix:getenv "APIKEY"))
  (setf lparallel:*kernel* (lparallel:make-kernel 32))
  (let* ((ips (lparallel:pmap 'vector
                              #'(lambda (x)
                                  (format nil "~{~A~^.~}"
                                          (reverse
                                           (uiop:split-string x :separator ".")))) argv))
         (endpoint "dnsbl.httpbl.org")
         (queries (lparallel:pmap 'vector #'(lambda (x)
                                              (format nil "~{~A~^.~}"
                                                      `(,*apikey* ,x ,endpoint))) ips)))
    (lparallel:pmap 'vector
                    #'(lambda (x)
                        (handler-case (sb-bsd-sockets:host-ent-address
                                       (sb-bsd-sockets:get-host-by-name x))
                          (error (c) (format t "Error: ~S~%" c))
                          (:no-error (c) (format t "~A: ~A~%" x c)))) queries))
  (lparallel:end-kernel :wait t))
