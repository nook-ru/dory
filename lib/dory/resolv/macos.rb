require 'colorize'

module Dory
  module Resolv
    module Macos
      def self.system_resolv_file
        '/etc/resolv.conf'
      end

      def self.port
        Dory::Config.settings[:dory][:resolv][:port] || 19323
      end

      def self.resolv_dir
        '/etc/resolver'
      end

      def self.resolv_file_names
        # on macos the file name should match the domain
        if Dory::Config.settings[:dory][:dnsmasq][:domain]
          [Dory::Config.settings[:dory][:dnsmasq][:domain]]
        elsif Dory::Config.settings[:dory][:dnsmasq][:domains]
          Dory::Config.settings[:dory][:dnsmasq][:domains].map{ |d| d[:domain] }
        else
          ['docker']
        end
      end

      def self.resolv_files
        self.resolv_file_names.map{ |f| "#{self.resolv_dir}/#{f}" }
      end

      def self.configured_to_use_dinghy
        Dory::Dinghy.match?(Dory::Config.settings[:dory][:resolv][:nameserver])
      end

      def self.nameserver
        ns = Dory::Config.settings[:dory][:resolv][:nameserver]
        Dory::Dinghy.match?(ns) ? Dory::Dinghy.ip : ns
      end

      def self.file_nameserver_line
        "nameserver #{self.nameserver}"
      end

      def self.file_comment
        '# added by dory'
      end

      def self.resolv_contents
        <<-EOF.gsub(' ' * 10, '')
          #{self.file_comment}
          #{self.file_nameserver_line}
          port #{self.port}
        EOF
      end

      def self.configure
        # have to use this hack cuz we don't run as root :-(
        unless Dir.exist?(self.resolv_dir)
          puts "Requesting sudo to create directory #{self.resolv_dir}".green
          Bash.run_command("sudo mkdir -p #{self.resolv_dir}")
        end
        self.resolv_files.each do |filename|
          puts "Requesting sudo to write to #{filename}".green
          Bash.run_command("echo -e '#{self.resolv_contents}' | sudo /usr/bin/tee #{Shellwords.escape(filename)} >/dev/null")
        end
      rescue DinghyError => e
        puts e.message.red
        false
      end

      def self.clean
        self.resolv_files.each do |filename|
          puts "Requesting sudo to delete '#{filename}'".green
          Bash.run_command("sudo rm -f #{filename}")
        end
      end

      def self.system_resolv_file_contents
        File.read(self.system_resolv_file)
      end

      def self.resolv_file_contents
        File.read(self.resolv_file)
      end

      def self.has_our_nameserver?
        self.resolv_files.all? do |filename|
          if File.exist?(filename)
            self.contents_has_our_nameserver?(File.read(filename))
          else
            false
          end
        end
      end

      def self.contents_has_our_nameserver?(contents)
        comment_match = contents =~ /#{self.file_comment}/
        port_match = contents =~ /port.#{self.port}/
        if configured_to_use_dinghy
          !!(comment_match && port_match)
        else
          nameserver_match = contents =~ /#{self.file_nameserver_line}/
          !!(comment_match && port_match && nameserver_match)
        end
      end
    end
  end
end
