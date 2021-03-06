# Copyright (c) 2015 Cisco and/or its affiliates.
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

# Make sure the module exists as the gemspec requires this file directly
module Cisco
end

# Add version number to Cisco::Shim namespace
module Cisco::Shim
  VERSION = '1.1.0-dev'

  gem_version = Gem::Version.new(Gem::VERSION)
  min_gem_version = Gem::Version.new('2.1.0')
  fail 'Required rubygems version >= 2.1.0' if gem_version < min_gem_version
end
