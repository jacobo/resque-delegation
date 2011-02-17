module Resque
  module Plugins
    module Delegation
      class Jobdata < Resque::Plugins::Meta::Metadata
        
        
        
        #need to implement a re-enQ method that only does so if I'm not already enQ'd
        
        #re-enQ should clear the 'finished_at' flag on the job meta-data
        #dQ should check that I'm not already finished (if so, exit without running)
        
        
      end
    end
  end
end
