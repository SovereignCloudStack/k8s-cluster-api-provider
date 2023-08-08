#!/usr/bin/sed -f
/^WORKER_MACHINE_COUNT:/{ a\
# Increase generation counter when changing flavor or k8s version or other MD settings
a\
WORKER_MACHINE_GEN: genw01
}
