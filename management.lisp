(require :asdf)
(require :uiop)
(asdf:load-system :cl-ppcre)

(defvar *choice* "")
(defvar *serverip* "")
(defvar *password* "")
(defvar *sslsecret* "")

(defvar *env-content*)

(defun help ()
  (format t "~%0 - Initilize docker containers")
  (format t "~%1 - Check container status")
  (format t "~%2 - Restart Activepieces")
  (format t "~%3 - Restart Twenty")
  (format t "~%4 - Update Activepieces")
  (format t "~%5 - Update Twenty")
  (format t "~%6 - Remove Twenty")
  (format t "~%7 - Backup Twenty - BROKEN")
  (format t "~%8 - Logs")
  (format t "~%9 - Install Docker")
  (format t "~%10 - Restart All Containers")
  (format t "~%11 - Install Twenty (WITHOUT AP)")
  (format t "~%12 - Install HTTPS Support")
  (format t "~%13 - Checklist")
  (format t "~%14 - Install SudleCRM")
  (format t "~%15 - Pull Quicklisp")
  (format t "~%16 - Add Swap")
  (format t "~%99 - Help")
  (format t "~%999 - Exit"))

(defun checklist ()
  (format t "~%Add Swap")
  (format t "~%Setup Nginx")
  (format t "~%Install Quicklisp")
  (format t "~%Install SudleCRM")
  (format t "~%Install HTTPS Support"))

(defun add-swapfile (&optional (size-gb 4))
  (handler-case
      (uiop:run-program "swapon --show | grep -q /swapfile"
                        :output nil :error-output nil)
    (error ()
      (format t "~&Creating ~AGB swapfile...~%" size-gb)
      (uiop:run-program (format nil "sudo fallocate -l ~AG /swapfile" size-gb)
                        :output t :error-output t)
      (uiop:run-program "sudo chmod 600 /swapfile"
                        :output t :error-output t)
      (uiop:run-program "sudo mkswap /swapfile"
                        :output t :error-output t)
      (uiop:run-program "sudo swapon /swapfile"
                        :output t :error-output t)
      (uiop:run-program "echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab"
                        :output t :error-output t)
      (format t "~&Swapfile created and enabled.~%"))))

(defun twenty-env ()
  (uiop:run-program
      (list "curl" "-o" ".env"
            "https://raw.githubusercontent.com/twentyhq/twenty/refs/heads/main/packages/twenty-docker/.env.example") :output t)

  (format t "Insert External IP and Port (eg 8.8.8.8:3000): ")
  (finish-output)
  (setf *serverip* (read-line))
  (format t "Enter new Postgres password: ")
  (finish-output)
  (setf *password* (read-line))

  ; load file
  (let ((env-path (merge-pathnames ".env" (uiop:getcwd))))
    ; Write Server URL
    (setf *env-content* (uiop:read-file-string env-path))
    (setf *env-content* (cl-ppcre:regex-replace
                      "#\\s*APP_SECRET=.*\\r?"
                      *env-content*
                      "APP_SECRET="))
    (setf *env-content* (cl-ppcre:regex-replace
                      "#\\s*PG_DATABASE_PASSWORD=.*\\r?"
                      *env-content*
                      "PG_DATABASE_PASSWORD="))
        (format t "~%MATCH: ~a" (cl-ppcre:scan "SERVER_URL=.*" *env-content*))
        (setf *env-content* (cl-ppcre:regex-replace
                              "SERVER_URL=.*\\r?"
                              *env-content*
                              (format nil "SERVER_URL=http://~a" *serverip*)))
        (format t "~%MATCH: ~a" (cl-ppcre:scan "PG_DATABASE_PASSWORD=.*" *env-content*))
    ; Write Postgres Password
    (setf *env-content* (cl-ppcre:regex-replace
                          "PG_DATABASE_PASSWORD=.*\\r?"
                          *env-content*
                          (format nil "PG_DATABASE_PASSWORD=~a" *password*)))
    ; Grab SSL Secret
    (setf *sslsecret* (string-trim '(#\Newline #\Space)
                        (uiop:run-program (list "openssl" "rand" "-base64" "32") :output :string)))
                        (format t "~%MATCH: ~a" (cl-ppcre:scan "APP_SECRET=.*" *env-content*))
    ; Write SSL Secret
    (setf *env-content* (cl-ppcre:regex-replace
                          "APP_SECRET=.*\\r?"
                          *env-content*
                          (format nil "APP_SECRET=~a" *sslsecret*)))
                          (format t "~%PREVIEW: ~a" (subseq *env-content* 0 200))
                          (format t "~%WRITING TO: ~a" env-path)
    ; Set permissions
    (uiop:run-program (list "sudo" "chmod" "644" (namestring env-path)) :output t)
    ; Write file
    (with-open-file (out env-path :direction :output :if-exists :supersede)
      (write-string *env-content* out))
    (format t "~%TWENTY CONFIGURED, BEGINNING INSTALL")))

(defun remove-twenty ()
  (uiop:run-program (list "sudo" "docker" "stop" "twenty-worker-1" "twenty-server-1" "twenty-db-1" "twenty-redis-1") :output t)
  (uiop:run-program (list "sudo" "docker" "rm" "twenty-worker-1" "twenty-server-1" "twenty-db-1" "twenty-redis-1") :output t)
  (uiop:run-program (list "bash" "-c" "sudo rm -rf ~/twenty") :output t)
  (format t "~%TWENTY REMOVED"))

(defun backup-twenty ()
  (uiop:run-program
    (list "bash" "-c"
          "sudo docker exec twenty-db-1 pg_dump -U postgres -l")
    :output t)
  (format t "~%CHECK DB NAMES ABOVE"))

(defun activepieces-networking ()
  (format t "NOT IMPLEMENTED"))

(defun restart-activepieces ()
  (uiop:run-program (list "sudo" "docker" "stop" "activepieces") :output t)
  (uiop:run-program (list "sudo" "docker" "start" "activepieces") :output t)
  (format t "~%RESTARTED"))

(defun restart-twenty ()
  (uiop:run-program (list "sudo" "docker" "stop" "twenty-worker-1" "twenty-server-1" "twenty-db-1" "twenty-redis-1") :output t)
  (uiop:run-program (list "sudo" "docker" "start" "twenty-worker-1" "twenty-server-1" "twenty-db-1" "twenty-redis-1") :output t)
  (format t "~%RESTARTED"))

(defun install-activepieces ()
  (format t "Enter Activepieces public URL (eg https://admin.sudlesystems.com): ")
  (finish-output)
  (let ((url (read-line)))
    (uiop:run-program
      (list "bash" "-c"
            (format nil "sudo docker rm -f activepieces 2>/dev/null; sudo docker run -d -p 8080:80 -v /root/.activepieces:/root/.activepieces --name activepieces -e AP_REDIS_TYPE=MEMORY -e AP_DB_TYPE=PGLITE -e AP_FRONTEND_URL=~a activepieces/activepieces:latest" url))
      :output t)))

(defun install-sudle ()
  (uiop:run-program "curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
                    :output t :error-output t)
  (uiop:run-program "sudo apt install -y nodejs git"
                    :output t :error-output t)
  (uiop:run-program "git clone git@github.com:liam-0398/LCRM.git"
                    :output t :error-output t)
  (uiop:run-program "cd LCRM/frontend && npm install"
                    :output t :error-output t)
  (uiop:run-program "cd LCRM/frontend && npm run build"
                    :output t :error-output t)
  (uiop:run-program "cd LCRM && sbcl --load crm.lisp"
                    :output t :error-output t)
  (uiop:run-program "cd LCRM && bash service_install.sh"
                    :output t :error-output t))

(defun install-twenty ()
  (ensure-directories-exist (merge-pathnames "twenty/" (user-homedir-pathname)))
  (uiop:with-current-directory ((merge-pathnames "twenty/" (user-homedir-pathname)))
    (twenty-env)
    (uiop:run-program
      (list "curl" "-o" "docker-compose.yml"
            "https://raw.githubusercontent.com/twentyhq/twenty/refs/heads/main/packages/twenty-docker/docker-compose.yml")
      :output t)
    (uiop:run-program (list "sudo" "docker" "compose" "up" "-d") :output t))
  (format t "~%TWENTY INSTALLED"))

 (defun install-quicklisp ()
  (handler-case
      (uiop:run-program "which sbcl" :output nil :error-output nil)
    (error ()
      (format t "~&SBCL not found, installing...~%")
      (uiop:run-program "sudo apt update" :output t :error-output t)
      (uiop:run-program "sudo apt install -y sbcl" :output t :error-output t)))
  (uiop:run-program "curl -O https://beta.quicklisp.org/quicklisp.lisp"
                    :output t :error-output t)
  (uiop:run-program
    "sbcl --non-interactive --load quicklisp.lisp --eval '(quicklisp-quickstart:install)' --eval '(ql:add-to-init-file)'"
    :output t :error-output t))

(defun update-activepieces ()
  (uiop:run-program (list "sudo" "docker" "stop" "activepieces") :output t)
  (uiop:run-program (list "sudo" "docker" "rm" "activepieces") :output t)
  (uiop:run-program (list "sudo" "docker" "pull" "activepieces/activepieces:latest") :output t)
  (install-activepieces)
  (format t "~%COMPLETED. Check output above."))

(defun update-twenty ()
  (uiop:with-current-directory ((merge-pathnames "twenty/" (user-homedir-pathname)))
    (uiop:run-program (list "sudo" "docker" "compose" "pull") :output t)
    (uiop:run-program (list "sudo" "docker" "compose" "up" "-d") :output t))
  (format t "~%TWENTY UPDATED"))

(defun install-docker ()
  (uiop:run-program
    (list "bash" "-c"
          "curl -fsSL https://get.docker.com | sh")
    :output t
    :error t)
  (format t "~%DOCKER INSTALLED"))


(defun init-docker ()
  (format t "~%INITIALIZING DOCKER CONTAINERS")
  (install-activepieces)
  (format t "~%Do you want twenty? 1 for yes, 0 for no.")
  (finish-output)
  (let ((input (read-line)))
    (when (equal input "1")
      (install-twenty))))

(defun health-check ()
  (format t "~%~a" (uiop:run-program (list "sudo" "docker" "ps" "-a") :output :string)))

(defun log-check ()
  (format t "~%~a" (uiop:run-program
    (list "sudo" "docker" "logs" "--tail" "10" "activepieces")
    :output :string))
  (format t "~%~a" (uiop:run-program
    (list "sudo" "docker" "logs" "--tail" "10" "twenty-server-1")
    :output :string))
  (format t "~%--- sudlecrm-backend ---~%~a" (uiop:run-program
    (list "sudo" "journalctl" "-u" "sudlecrm-backend" "-n" "10" "--no-pager")
    :output :string))
  (format t "~%--- sudlecrm-frontend ---~%~a" (uiop:run-program
    (list "sudo" "journalctl" "-u" "sudlecrm-frontend" "-n" "10" "--no-pager")
    :output :string)))

(defun restart-all ()
  (uiop:run-program
    (list "sh" "-c" "sudo docker restart $(sudo docker ps -q)")
    :output t
    :error-output t))
    
(defun install-https-support ()
  (format t "~%~a" (uiop:run-program
    (list "sudo" "apt" "install" "nginx" "python3-certbot-nginx")
    :output :string))
    (format t "~% ADJUST CONFIG FILES AND START")
    (format t "~%~%~a" "sudo ln -s /etc/nginx/sites-available/*DOMAIN* /etc/nginx/sites-enabled/")
(format t "~%~a" "sudo nginx -t")
(format t "~%~a" "sudo systemctl reload nginx")
(format t "~%~a" "sudo certbot --nginx -d *SUBDOMAIN1*"))

(defun switchboard ()
  (format t "~%Enter 0 to install containers or 99 for help.")
  (format t "~%>> ")
  (finish-output)
  (setf *choice* (read-line))
  (cond
    ((equal *choice* "0") (init-docker))
    ((equal *choice* "1") (health-check))
    ((equal *choice* "2") (restart-activepieces))
    ((equal *choice* "3") (restart-twenty))
    ((equal *choice* "4") (update-activepieces))
    ((equal *choice* "5") (update-twenty))
    ((equal *choice* "6") (remove-twenty))
    ((equal *choice* "7") (backup-twenty))
    ((equal *choice* "8") (log-check))
    ((equal *choice* "9") (install-docker))
    ((equal *choice* "10") (restart-all))
    ((equal *choice* "11") (install-twenty))
    ((equal *choice* "12") (install-https-support))
    ((equal *choice* "13") (checklist))
    ((equal *choice* "14") (install-sudle))
    ((equal *choice* "15") (install-quicklisp))
    ((equal *choice* "15") (add-swapfile))
    ((equal *choice* "99") (help))
    ((equal *choice* "999") (sb-ext:exit))
    (t (format t "~%Invalid option."))))

(defun main ()
  (format t "~%INITILIZATION SOFTWARE~%")
  (loop until (equal *choice* "999")
  do (switchboard)))

;(main)

; UNCOMMENT AND COMMENT MAIN THEM --LOAD TO COMPILE TO BINARY
(sb-ext:save-lisp-and-die "management-console"
  :toplevel #'main
  :executable t)
