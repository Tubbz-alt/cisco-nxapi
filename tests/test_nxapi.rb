# November 2014, Glenn F. Matthews
#
# Copyright (c) 2014-2015 Cisco and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative 'basetest'
require_relative '../lib/cisco_os_shim'

include Cisco::Shim::NXAPI

# TestNxapi - NXAPI client unit tests
class TestNxapi < TestCase
  @@client = nil # rubocop:disable Style/ClassVars

  def client
    unless @@client
      client = Client.new(address, username, password)
      client.cache_enable = true
      client.cache_auto = true
      @@client = client # rubocop:disable Style/ClassVars
    end
    @@client
  end

  # Test cases for new NXAPI client APIs

  def test_config_string
    client.config("int et1/1\ndescr panda\n")
    run = client.show('show run int et1/1')
    desc = run.match(/description (.*)/)[1]
    assert_equal(desc, 'panda')
  end

  def test_config_array
    client.config(['int et1/1', 'descr elephant'])
    run = client.show('show run int et1/1')
    desc = run.match(/description (.*)/)[1]
    assert_equal(desc, 'elephant')
  end

  def test_config_invalid
    e = assert_raises CliError do
      client.config(['int et1/1', 'exit', 'int et1/2', 'plover'])
    end
    assert_match(/plover.*% Invalid command\n/, e.message)
    assert_equal('plover', e.rejected_input)
    assert_equal(['int et1/1', 'exit', 'int et1/2'], e.successful_input)

    assert_equal("% Invalid command\n", e.clierror)
    assert_equal('CLI execution error', e.msg)
    assert_equal('400', e.code)
  end

  def test_exec
    result = client.exec('echo hello')
    assert_equal(result.strip, 'hello')
  end

  def test_exec_invalid
    e = assert_raises CliError do
      client.exec('xyzzy')
    end
    assert_match(/xyzzy.*Syntax error/, e.message)
    assert_equal('xyzzy', e.rejected_input)
    assert_empty(e.successful_input)

    assert_match(/Syntax error/, e.clierror)
    assert_equal('Input CLI command error', e.msg)
    assert_equal('400', e.code)
  end

  def test_exec_too_long
    assert_raises Cisco::Shim::RequestNotSupported do
      client.exec('0' * 500_000)
    end
  end

  def test_show_ascii_default
    result = client.show('show hostname')
    s = @device.cmd('show hostname')
    assert_equal(result.strip, s.split("\n")[1].strip)
  end

  def test_show_ascii_invalid
    assert_raises CliError do
      client.show('show plugh')
    end
  end

  def test_element_show_ascii_incomplete
    assert_raises CliError do
      client.show('show ')
    end
  end

  def test_show_ascii_explicit
    result = client.show('show hostname', :ascii)
    s = @device.cmd('show hostname')
    assert_equal(result.strip, s.split("\n")[1].strip)
  end

  def test_show_ascii_empty
    result = client.show('show hostname | include foo | exclude foo', :ascii)
    assert_equal('', result)
  end

  def test_show_structured
    result = client.show('show hostname', :structured)
    s = @device.cmd('show hostname')
    assert_equal(result['hostname'], s.split("\n")[1].strip)
  end

  def test_show_structured_invalid
    assert_raises CliError do
      client.show('show frobozz', :structured)
    end
  end

  def test_show_structured_unsupported
    # TBD: n3k DOES support structured for this command,
    #  n9k DOES NOT support structured for this command
    assert_raises Cisco::Shim::RequestNotSupported do
      client.show('show snmp internal globals', :structured)
    end
  end

  def test_connection_refused
    @device.cmd('configure terminal')
    @device.cmd('no feature nxapi')
    @device.cmd('end')
    client.cache_flush
    assert_raises Cisco::Shim::ConnectionRefused do
      client.show('show version')
    end
    assert_raises Cisco::Shim::ConnectionRefused do
      client.exec('show version')
    end
    assert_raises Cisco::Shim::ConnectionRefused do
      client.config('interface Et1/1')
    end
    # On the off chance that things behave differently when NXAPI is
    # disabled while we're connected, versus trying to connect afresh...
    @@client = nil # rubocop:disable Style/ClassVars
    assert_raises Cisco::Shim::ConnectionRefused do
      client.show('show version')
    end
    assert_raises Cisco::Shim::ConnectionRefused do
      client.exec('show version')
    end
    assert_raises Cisco::Shim::ConnectionRefused do
      client.config('interface Et1/1')
    end

    @device.cmd('configure terminal')
    @device.cmd('feature nxapi')
    @device.cmd('end')
  end

  def test_unauthorized
    def client.password=(new) # rubocop:disable Style/TrivialAccessors
      @password = new
    end
    client.password = 'wrong_password'
    client.cache_flush
    assert_raises HTTPUnauthorized do
      client.show('show version')
    end
    assert_raises HTTPUnauthorized do
      client.exec('show version')
    end
    assert_raises HTTPUnauthorized do
      client.config('interface Et1/1')
    end
    client.password = password
  end

  def test_unsupported
    # Add a method to the NXAPI that sends a request of invalid type
    def client.hello
      req('hello', 'world')
    end

    assert_raises Cisco::Shim::RequestNotSupported do
      client.hello
    end
  end

  def test_smart_create
    autoclient = Cisco::Shim::Client.create(address, username, password)
    assert_equal(Cisco::Shim::NXAPI::Client, autoclient.class)
    assert_equal('NXAPI', autoclient.api)
  end
end
