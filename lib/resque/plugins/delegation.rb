require 'resque/plugins/meta'

module Resque
  module Plugins
    module Delegation
      def self.extended(mod)
        mod.extend(Resque::Plugins::Meta)
      end

      class Step
        def initialize(args, run_last = false, &block)
          @run_last = run_last
          @signature = args.map{|a| a.to_s}.join(" ")
          if args.size == 1
            #no inputs or output
            @inputs = []
          elsif args.size >= 2
            unless @run_last
              @output = args.pop.to_s
            end
            @inputs = []
            args.each_with_index do |a, index|
              if index % 2 == 1
                @inputs << a.to_s
              end
            end
          else
            raise ArgumentError, "invalid arguments #{args.inspect}"
          end
          @block = block
        end
        attr_reader :block, :signature, :inputs, :output, :run_last
        # attr_accessor :run_last
        # attr_reader :step_name, :what_it_makes, :block
        def run(available_inputs)
          block_args = @inputs.map do |input_name|
            available_inputs[input_name]
          end
          @block.call(*block_args)
        end
      end
      
      #TODO:
      #
      # Need a way to edit meta data BEFORE a job is enQ'd 
      # so that we can we sure that data is available on dQ
      # 
      # Need a way to "Lock" editing of the meta data on a job
      # so other editors of job data must wait before editing job
      # (2 jobs marking a step done and then, therefore re-enQ-ing the parent)
      #
      # need a way to mark a job as already enQ'd (and not yet running)
      # so that if the tomato just re-enQ'd the sandwich, the cheese will see it on the Q and let it be
      # 
      # basically, there should be a lock such that if there are any child jobs still enQ'd for a job
      # it should not run but prioritize the child jobs first

      class StepDependency
        def initialize(job_class, args)
          @job_class = job_class
          @job_args = args
        end
        attr_reader :job_class, :job_args
      end

      def run_steps(meta_id, *args)
        @step_list = []
        @meta = self.get_meta(meta_id)
        # puts "I have meta of: " + @meta.inspect

        steps(*args)
        #TODO: raise error if there are duplicate steps defined?

        # require 'pp'
        # pp @step_list

        #figure out which step we are on from meta data
        steps_ran = @meta["steps_ran"] ||= []
        puts "my steps_ran are #{steps_ran.inspect}"
        # @step_list.map{ |step| step.signature }
        available_inputs = @meta["available_inputs"] ||= {}
        puts "my available_inputs are #{available_inputs.inspect}"

        #run last step if no more steps are needed
        @step_list.each do |step|
          if steps_ran.include?(step.signature)
            #already ran
          elsif step.run_last
            puts "Can't run last step #{step.signature} yet"
            #this is the last step, only run if all other steps are run
          elsif (step.inputs - available_inputs.keys).empty?
            #all of the steps needed inputs are available
            #run!
            result = step.run(available_inputs)
            if result.is_a?(StepDependency)
              #TODO: what if the child job is dQ'd before caller has a chance to set parent_job
              child_job = result.job_class.enqueue(*result.job_args)
              child_job["parent_job"] = [self, meta_id, args]
              child_job["expected_output"] = step.output
              child_job["signature_from_parent"] = step.signature
              child_job.save
            else
              if step.output
                available_inputs[step.output] = result
              end
              puts "available_inputs are now #{available_inputs.inspect}"
              @meta["steps_ran"] << step.signature
            end
          else
            puts "waiting before we can run step #{step.signature} -- need #{step.inputs}"
          end
        end
        
        if steps_ran.size + 1 == @step_list.size
          puts "now running last step"
          step = @step_list.last
          result = step.run(available_inputs)
          if @meta["parent_job"]          
            puts "#{meta_id} has parent"
            parent_job_class_name, parent_meta_id, parent_args = @meta["parent_job"]
            parent_job_class = const_get(parent_job_class_name)
            parent_meta = parent_job_class.get_meta(parent_meta_id)
            if expected_output = @meta["expected_output"]
              parent_meta["available_inputs"][expected_output] = result
              parent_meta.save
            end
            if @meta["signature_from_parent"]
              parent_meta["steps_ran"] << @meta["signature_from_parent"]
              parent_meta.save
            end
            Resque.enqueue(parent_job_class, parent_meta_id, *parent_args)
          end
          @meta["steps_ran"] << step.signature
        end
        @meta.save
      end

      def step(*args, &block)
        @step_list << Step.new(args, &block)
      end
      
      def last_step(*args, &block)
        @step_list << Step.new(args, true, &block)
      end
      
      def depend_on(job_class, *args)
        StepDependency.new(job_class, args)
      end

    end
  end
end