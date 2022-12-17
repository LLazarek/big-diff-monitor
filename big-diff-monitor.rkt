#lang at-exp rscript

(main
 #:arguments ([(hash-table ['delta-size (app string->number delta-size)]
                           ['notify-cmd notification-cmd])
               files-to-watch]
              #:once-each
              [("-d" "--delta")
               'delta-size
               ("A drop in file size over this ratio causes notification. "
                "Default: 0.25")
               #:collect {"ratio in [0, 1]" take-latest "0.25"}]
              [("-n" "--notify-cmd")
               'notify-cmd
               ("Command to use to notify of a change."
                "May contain '%file' and '%delta', which will be replaced."
                "Default: `notify-send '%file lost %delta% of its content!'`")
               #:collect {"command" take-latest "notify-send '%file lost %delta% of its content!'"}]
              #:args file-paths)
 #:check [(andmap path-to-existant-file? files-to-watch)
          @~a{Can't find @(filter-not path-to-existant-file? files-to-watch)}]

 (define notification-delta (- delta-size))

 (define (notify-of-change-in! changed-file delta-ratio)
   (define cmd
     (string-replace (string-replace notification-cmd "%file" changed-file)
                     "%delta" (~r (* -100 delta-ratio) #:precision 0)))
   (system cmd))

 (define starting-info
   (for/hash ([file (in-list files-to-watch)])
     (values (filesystem-change-evt file)
             (list file (file-size file)))))
 (displayln @~a{
                Watching:
                @(pretty-format (hash-values starting-info))
                })
 (let loop ([file-info starting-info])
   (define changed-file-evt (apply sync (hash-keys file-info)))
   (match-define (list changed-file previous-size)
     (hash-ref file-info changed-file-evt))
   (sleep 0.05)
   (define current-size (file-size changed-file))
   (define delta-ratio (- (- 1 (/ current-size previous-size))))
   (when (< delta-ratio notification-delta)
     (notify-of-change-in! changed-file delta-ratio))
   (loop (hash-set (hash-remove file-info changed-file-evt)
                   (filesystem-change-evt changed-file)
                   (list changed-file current-size)))))
