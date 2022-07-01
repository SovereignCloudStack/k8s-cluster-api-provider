#!/usr/bin/sed -f
/^CONTROL_PLANE_MACHINE_COUNT:/{ a\
# Increase generation counter when changing flavor or k8s version or other MD settings
a\
CONTROL_PLANE_MACHINE_GEN: genc01
}
