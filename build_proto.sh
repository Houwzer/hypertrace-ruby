protoc --ruby_out=lib/hypertrace/config \
       --proto_path=agent-config/proto/hypertrace/agent/config/v1 \
        ./agent-config/proto/hypertrace/agent/config/v1/config.proto