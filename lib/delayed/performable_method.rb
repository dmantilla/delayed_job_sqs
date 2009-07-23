module Delayed
  class PerformableMethod < Struct.new(:object, :method, :args)
    CLASS_STRING_FORMAT = /^CLASS\:([A-Z][\w\:]+)$/
    AR_STRING_FORMAT    = /^AR\:([A-Z][\w\:]+)\:(\d+)$/

    def initialize(object, method, args)
      raise NoMethodError, "undefined method `#{method}' for #{self.inspect}" unless object.respond_to?(method)

      self.object = dump(object)
      self.args   = args.map { |a| dump(a) }
      self.method = method.to_sym
    end
    
    def display_name  
      case self.object
      when CLASS_STRING_FORMAT then "#{$1}.#{method}"
      when AR_STRING_FORMAT    then "#{$1}##{method}"
      else "Unknown##{method}"
      end      
    end

    def display_class_name
      case self.object
      when CLASS_STRING_FORMAT then $1
      when AR_STRING_FORMAT    then $1
      else "Unknown"
      end
    end

    def perform
      load(object).send(method, *args.map{|a| load(a)})
    #rescue ActiveRecord::RecordNotFound
      # We cannot do anything about objects which were deleted in the meantime
      true
    end

    # Display a friendlier view of the method to be executed before the actual execution
    def examine
      obj = load(object)
      # if the method starts with "deliver_" assumes it's an ActionMailer object
      if method.to_s =~ /^deliver_(.*)/
        create_method = "create_#{$1}"
        tmail_obj = obj.send(create_method.intern, *args.map{|a| load(a)})
        tmail_obj.to_s
      else
        display_name
      end
    end

    private

    def load(arg)
      case arg
      when CLASS_STRING_FORMAT then $1.constantize
      when AR_STRING_FORMAT    then $1.constantize.find($2)
      else arg
      end
    end

    def dump(arg)
      case arg
      when Class              then class_to_string(arg)
      when ActiveRecord::Base then ar_to_string(arg)
      else arg
      end
    end

    def ar_to_string(obj)
      "AR:#{obj.class}:#{obj.id}"
    end

    def class_to_string(obj)
      "CLASS:#{obj.name}"
    end
  end
end