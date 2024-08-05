# Copyright Vespa.ai. All rights reserved.
class Result
  attr_reader :returncode, :errorstring

  def initialize(args)
    @returncode = args.returncode.to_i

    if args.errorstring.class == String
      @errorstring = args.errorstring
    else
      @errorstring = ""
    end
  end

  def to_s
    if @returncode == 0
      "Result is 0"
    else
      "Result is " + @returncode.inspect + " : " + @errorstring.inspect
   end
  end
end
