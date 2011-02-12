require 'resque'
require 'resque/plugins/delegation'

class WhatHappened
  require 'tempfile'  
  def self.reset!
    @what_happened = Tempfile.new("what_happened")
  end
  def self.what_happened
    File.read(@what_happened.path)
  end
  def self.record(*event)
    @what_happened.write(event.to_s)
    @what_happened.flush
  end
end

class BasicJob
  extend Resque::Plugins::Delegation
  @queue = :test
    
  def self.perform(*args)
    begin
      WhatHappened.record(self, args)
    rescue => e
      puts e.inspect
      puts e.backtrace.join("\n")
    end
  end
end


describe "the basics" do
  before do
    WhatHappened.reset!
    Resque.redis.flushall
  end
  
  it "works" do
    meta = BasicJob.enqueue('foo', 'bar')
    worker = Resque::Worker.new(:test)
    worker.work(0)
    meta = BasicJob.get_meta(meta.meta_id)
    WhatHappened.what_happened.should == "BasicJob#{meta.meta_id}foobar"
  end
end

class BaseJobWithPerform
  def self.perform(*args)
    begin
      puts "Running #{self} with args #{args.inspect}"
      run_steps(*args)
    rescue => e
      puts e.inspect
      puts e.backtrace.join("\n")
    end      
  end  
end

class Sandwhich < BaseJobWithPerform
  extend Resque::Plugins::Delegation
  @queue = :test

  def self.steps(tomato_color, cheese_please)
    step "assemble the", :bread do
      depend_on(Bread)
    end
    step "fetch a", :tomato do
      depend_on(Tomato, tomato_color)
    end
    step "do something with no inputs" do
      puts "did it"
    end
    step "slice the ", :tomato, " and make", :tomato_slices do |tomato|
      tomato.split(",")
    end
    step "fetch the", :cheese_slices do
      if cheese_please
        depend_on(Cheese)
      else
        []
      end
    end
    last_step("assemble", :bread, "with", :tomato_slices, "with", :cheese_slices
    ) do |bread, tomato_slices, cheese_slices|
      sandwhich = bread[0]
      tomato_slices.each do |tomato_slice|
        sandwhich += tomato_slice
        if cheese_slice = cheese_slices.pop
          sandwhich += cheese_slice
        end
      end
      cheese_slices.each do |cheese_slice|
        sandwhich += cheese_slice        
      end
      sandwhich += bread[1]
      WhatHappened.record(sandwhich)      
    end
  end

end

class Bread < BaseJobWithPerform
  extend Resque::Plugins::Delegation
  @queue = :test

  def self.steps
    step "fetch ", :flour do
      depend_on(WheatGrinding)
    end
    step "fetch ", :yeast do
      "mmm yeasty"
    end
    step "mix ", :flour, "and", :yeast, "with water, and bake ", :bread do |flour, yeast|
      puts "combining #{flour} and #{yeast}"
      "(|||||)"
    end
    last_step "return 2 slices of ", :bread do |bread|
      all_slices = bread.chars.to_a.reverse
      [all_slices.pop, all_slices.pop]
    end
  end
end

class WheatGrinding < BaseJobWithPerform
  extend Resque::Plugins::Delegation
  @queue = :test

  def self.steps
    last_step "return some flour" do
      "white powder"
    end    
  end

end

class Tomato < BaseJobWithPerform
  extend Resque::Plugins::Delegation
  @queue = :test

  def self.steps(color)
    last_step "return tomato" do
      "T,T,T"
    end
  end
end

class Cheese < BaseJobWithPerform
  extend Resque::Plugins::Delegation
  @queue = :test

  def self.steps
    last_step "return cheese" do
      #hmm, we can do things like pause here 
      #and wait for a decision about what kind of cheese
      #thus it's like the parent job is suspended, and the reason in inspectable
      ["C","C","C","C"]
    end
  end
end

describe "sandwhich" do
  before do
    WhatHappened.reset!
    Resque.redis.flushall
  end
  
  it "makes one" do
    meta = Sandwhich.enqueue('red', true)
    worker = Resque::Worker.new(:test)
    worker.work(0)
    # meta = Sandwhich.get_meta(meta.meta_id)
    WhatHappened.what_happened.should == "(TCTCTCC|"
  end

  #should do a test where the job fails, 
  #but because the meta data is available
  #we can make some correction and re-run the job and it succeeds

  #how does the failed job Q work?

end