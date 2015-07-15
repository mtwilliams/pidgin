module Pidgin
  module VERSION #:nodoc:
    MAJOR, MINOR, PATCH, PRE = [0, 0, 2, 'pre']
    STRING = [MAJOR, MINOR, PATCH, PRE].compact.join('.')
  end

  def self.version
    Pidgin::VERSION::STRING
  end
end

