class LobaClass
  include Loba

  def base_ts
    Loba.ts
  end

  def base_val
    _bv = "BENJAMIN"
    Loba::val :_bv
#    Loba::val self.methods.sort.uniq
  end

  def self.classbase_ts
    Loba::ts
  end

  def self.classbase_val
    _cw = "CLAUDIA"
    Loba::val :_cw
  end
end
