module Term
  module Events
    def self.included(cls)
      cls.extend(ClassMethods)
    end

    module ClassMethods
      def events(*args)
        include Methods
        define_singleton_method(:signal_names) do
          args
        end
      end
    end

    module Methods
      # Add a callback function.  If "ident" is passed, it is used as the
      # identifier to this connection, otherwise, one is automatically generated.
      # returns a value that can be passed to "disconnect"
      def connect(signal, ident = nil, &block)
        @ident_counter ||= 0
        # Generate IDs that are unlikely to clash with low integers
        ident ||= ((1 << 30) | (@ident_counter += 1))

        unless connections.has_key?(signal)
          fail ArgumentError, "invalid signal name: #{signal.inspect}"
        end
        connections[signal] ||= {}
        connections[signal][ident] = block
        return ident
      end

      # Disconnect a watcher, identified by ident.  ident was returned from an
      # earlier call to connect.  If "name" is passed, it must be a callback name,
      # or array of callback names, and the disconnect will be limited to idents
      # connected to those signal names.  If no names are given, ident is
      # disconnected from all sets.
      # If ident is omitted, call connections made to "name" are removed.
      def disconnect(ident = nil, signals: nil)
        Array(signals || connections.keys).each do |signal|
          unless connections.has_key?(signal)
            fail ArgumentError, "invalid signal name: #{signal.inspect}"
          end

          if ident.nil?
            connections[signal] = nil
          else
            connections[signal].delete(ident)
          end
        end
      end

      private

      def connections
        @connections ||= Hash[self.class.signal_names.zip([])]
      end

      # Emit a signal with arguments
      def emit(signal, *args)
        unless connections.has_key?(signal)
          fail ArgumentError, "invalid signal name: #{signal.inspect}"
        end

        Array(connections[signal]).each do |key, func|
          func.call(self, *args)
        end
      end

    end
  end
end