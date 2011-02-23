Resque::Plugins::Meta.class_eval do

  def after_perform_meta(meta_id, *args)
    if meta = get_meta(meta_id)
      if step_count = meta["step_count"]
        if step_count == meta["steps_ran"].size
          meta.finish!
        end
      else
        meta.finish!
      end
    end
  end


end