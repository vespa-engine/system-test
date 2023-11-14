# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

# Utility for executing shell commands in a test

class Executor

  def initialize(short_hostname)
    @short_hostname = short_hostname
  end

  # Executes _command_. Raises an exception if the exitstatus
  # was non-zero, unless :exceptiononfailure is set to false. Echoes output
  # from the command unless :noecho.
  # Returns stdout and stderr of the command (max 100kB). If :exitcode, returns an array
  # containing exit code and stdout/stderr
  #
  # Params:
  # +command+:: the command to execute
  # +testcase+:: the test case which should receive output from this, or null if none
  # +params+:: parameters to the execution (see code below)
  def execute(command, testcase, params={})
    if params[:exceptiononfailure].nil?
      if params[:exitcode]
        exceptiononfailure = false
      else
        exceptiononfailure = true
      end
    else
      exceptiononfailure = params[:exceptiononfailure]
    end

    testcase_output("#{@short_hostname}$ #{command}", testcase) if not params[:noecho]
    # wrap command in order to see stderr when command is not found
    if params[:stderr]
      command = "( #{command} ) 2>&1"
    else
      command = "( #{command} ) 2>/dev/null"
    end

    stdout = IO.popen(command)
    data = ""
    batch_lines = ""
    interval_start = Time.now.to_i
    while line = stdout.gets
      duration = Time.now.to_i - interval_start
      batch_lines = batch_lines + line

      # only send back output through DRb once every 2 seconds to avoid using up all resources
      if duration > 2
        testcase_output(batch_lines, testcase, false) if not params[:noecho]
        batch_lines = ""
        interval_start = Time.now.to_i
      end
      data = data + line;
    end
    testcase_output(batch_lines, testcase, false) if not params[:noecho]
    stdout.close

    maxsize = 200*1024
    if (data.length < maxsize)
      output = data
    else
      output = data[-maxsize..-1] + "\n\nStdout buffer for command '#{command}' was too large, last #{maxsize/1024}KB returned\n"
    end

    if exceptiononfailure && $?.exitstatus != 0
      ex = ExecuteError.new("non-zero exit status (#{$?.exitstatus.to_i}) from #{command}")
      ex.output = output
      raise ex
    end

    # check that the output won't be too large for passing
    # through DRb, setting 100kb as a hard limit
    if params[:exitcode]
      return [$?.exitstatus.to_s, output]
    else
      return output
    end
  end

  # Output _str_ to node running testcase
  # TODO: Make private
  def testcase_output(str, testcase, newline=true)
    testcase.output(str, newline) if testcase
  end

end
