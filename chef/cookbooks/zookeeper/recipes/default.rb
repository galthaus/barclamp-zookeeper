#
# Cookbook Name: zookeeper
# Recipe: default.rb
#
# Copyright (c) 2011 Dell Inc.
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
#

#######################################################################
# Begin recipe transactions
#######################################################################
debug = node[:zookeeper][:debug]
Chef::Log.info("BEGIN zookeeper") if debug

# Configuration filter for our environment
env_filter = " AND environment:#{node[:zookeeper][:config][:environment]}"

# Install the zookeeper base package.
package "hadoop-zookeeper" do
  action :install
end

# Install the zookeeper server package.
package "hadoop-zookeeper-server" do
  action :install
end

# Define the server service.
service "hadoop-zookeeper-server" do
  supports :status => true, :start => true, :stop => true, :restart => true
end

=begin
# Configure log4j. 
template "/etc/zookeeper/log4j.properties" do
  mode 0644
  source "log4j.properties.erb"
  notifies :restart, resources(:service => "hadoop-zookeeper-server")
end
=end

# Find the zookeeper servers. 
servers = []
search(:node, "roles:hadoop-edgenode#{env_filter}") do |n|
  ipaddress = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
  obj = n.clone
  obj[:ipaddress] = ipaddress
  Chef::Log.info("ZOOKEEPER SERVER [#{obj[:ipaddress]}") if debug
  servers << obj 
end
servers.sort! { |a, b| a.name <=> b.name }
node[:zookeeper][:servers] = servers
node.save

# Enumerate the server listing.
myip = BarclampLibrary::Barclamp::Inventory.get_network_by_type(node,"admin").address
Chef::Log.info("MY IP [#{myip}") if debug
myid = servers.collect { |n| n[:ipaddress] }.index(myip)
Chef::Log.info("MY ID [#{myid}") if debug
template "#{node[:zookeeper][:data_dir]}/myid" do
  source "myid.erb"
  variables(:myid => myid)
end

# Write the zookeeper configuration file.
template "/etc/zookeeper/zoo.cfg" do
  source "zoo.cfg.erb"
  mode 0644
  variables(:servers => servers)
  notifies :restart, resources(:service => "hadoop-zookeeper-server")
end

# Start the zookeeper server.
service "hadoop-zookeeper-server" do
  action [ :enable, :start ]
  running true
  supports :status => true, :start => true, :stop => true, :restart => true
end

#######################################################################
# End of recipe transactions
#######################################################################
Chef::Log.info("END zookeeper") if debug
