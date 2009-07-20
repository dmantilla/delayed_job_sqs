module Delayed

  class DeserializationError < StandardError
  end

  class Job
    MAX_RUN_TIME = 4.hours

    ParseObjectFromYaml = /\!ruby\/\w+\:([^\s]+)/

    def initialize(message)
      @message = message
      @logger = defined?(RAILS_DEFAULT_LOGGER) ? RAILS_DEFAULT_LOGGER : Logger.new(STDOUT)
    end

    def payload_object
      @payload_object ||= deserialize(@message.to_s)
    end

    def name
      @name ||= begin
        payload = payload_object
        if payload.respond_to?(:display_name)
          payload.display_name
        else
          payload.class.name
        end
      end
    end

    def run(max_run_time = MAX_RUN_TIME)
      begin
        runtime = Benchmark.realtime do
          invoke_job # TODO: raise error if takes longer than max_run_time
        end
        # TODO : warn if runtime > max_run_time
        @logger.info "* [JOB] #{name} completed after %.4f" % runtime
        # The message is finally delete from the queue
        @message.delete
        true
      rescue Exception => e
        log_error(e)
        false # work failed
      end

    end

    # This is a good hook if you need to report job processing errors in additional or different ways
    def log_error(error)
      @logger.error "* [JOB] #{name} failed with #{error.class.name}: #{error.message}"
      @logger.error error.backtrace.inspect
    end

    # Moved into its own method so that new_relic can trace it.
    def invoke_job
      payload_object.perform
    end

    # Add a job to the queue
    def self.enqueue(*args, &block)
      sqs_queue = args.shift
      raise ArgumentError, 'SQS Queue was not provided' unless sqs_queue.is_a? RightAws::SqsGen2::Queue

      object = block_given? ? EvaledJob.new(&block) : args.shift

      unless object.respond_to?(:perform) || block_given?
        raise ArgumentError, 'Cannot enqueue items which do not respond to perform'
      end

      sqs_queue.send_message object.to_yaml
    end

    # Do num jobs and return stats on success/failure.
    # Exit early if interrupted.
    def self.work_off(sqs_queue)
      exit_flag = false
      until($exit)
        success, failure = 0, 0

        while(message = sqs_queue.receive)
          if message.to_s == 'stop'
            exit_flag = true
            break
          end
          
          case Job.new(message).run
          when true
              success += 1
          when false
              failure += 1
          else
            break  # leave if no work could be done
          end
          break if $exit # leave if we're exiting
        end
        
        break if exit_flag
        
        puts "Success: #{success}, Failures: #{failure}"
        sleep(60)
      end
    end

  private

    def deserialize(source)
      handler = YAML.load(source) rescue nil

      unless handler.respond_to?(:perform)
        if handler.nil? && source =~ ParseObjectFromYaml
          handler_class = $1
        end
        attempt_to_load(handler_class || handler.class)
        handler = YAML.load(source)
      end

      return handler if handler.respond_to?(:perform)

      raise DeserializationError,
        'Job failed to load: Unknown handler. Try to manually require the appropiate file.'
    rescue TypeError, LoadError, NameError => e
      raise DeserializationError,
        "Job failed to load: #{e.message}. Try to manually require the required file."
    end

  end

  class EvaledJob
    def initialize
      @job = yield
    end

    def perform
      eval(@job)
    end
  end
end
