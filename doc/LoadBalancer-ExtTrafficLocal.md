# Why `externalTrafficPolicy: local`?

Setting up the nginx ingress controller from the upstream deployment templates
using the `externalTrafficPolicy: local` setting and -- without any special
treatment -- results in a service that is only partially working: Only requests
that the LoadBalancer happens to route at the node where the nginx container is
running get a response.

nginx could just use the `cluster` setting instead and kube-proxy would forward
the network packets. There are two reasons for nginx not to do that

1. Having a load-balancer balance the traffic to a node that is not active just
   to have kube-proxy forward it to the active node does not make much sense.
   It creates an unecessary hop and makes the LoadBalancer pretty useless.

2. Packets forwarded by kube-proxy do not carry the original client IP, so any
   source IP dependant handling in nginx (filtering, QoS, ...) will not be
   possible.

# Getting it to work for managed ingress

There does not seem to be a standard mechanism where k8s tells the LoadBalancer (LB)
which backend members are active, but the load-balancer can find this out by using
a health-monitor that probes for the availability of the service and then takes
the inactive nodes out of the rotation. Should the container be rescheduled on
some other node, the health-monitor will adapt within a few seconds.

Since SCS R2, the deployed nginx-ingress deployment is patched to carry a service
annotation (OpenStack specific, sigh) that enables the health-monitor for the LB in
front of the ingress. This results in traffic to flow.

This covers the nginx ingress controller that is deployed by setting`
 DEPLOY_NGINX_INGRESS: true` with the `create_cluster.sh` or `apply_nginx_ingress.sh`.
That the ingress we call the "managed ingress".

For the ingress service to see the client IPs, more is needed. The Octavia LB
as well as the nginx service both support the proxy protocol, which can be used to
communicate the real client IP. We had plumbing included which we disabled by
default prior to releasing R2, because it broke the access to ingress from
software that runs inside the cluster.

A workaround for this has been implemented, so the default is
`NGINX_USE_PROXY: true` as of R4. So the managed nginx ingress service
does work reliably and gets the client IPs.

# Getting it to work in general

Users that deploy their own nginx or other services with `externalTrafficPolicy: local`
won't be helped by the annotations done by the SCS cluster management. They will
have to do similar custom patching or revert to a `cluster` policy and forego the
visibility on real client IPs.

A generic solution to this would be a different kind of LB that does work at the
networking layer 3 (routing), so the (TCP) connections are not terminated at the
LB and then data being forwarded on a new connection to the backend member, but
the routing would create a direct connection. Google (with Direct Server Return, DSR)
and Azure support such LB modes.

As it turns out, on OpenStack clouds that use OVN as networking (SDN) layer, the OVN
loadbalancer does almost deliver what's needed.

# OVN provider LoadBalancer

The OVN provider for the load-balancer does create direct flows to the chosen backend
member, so no proxy protocol (or similar hacks) are needed to make the backend service
see the client IPs. This has been validated (and can even be monitored by openstack-health-monitor)
on SCS clouds that use OVN.

A health-monitor is still needed to ensure that only active members receive requests.
There are unfortunately two problems with the health-monitoring on the OVN provider:
* The health-monitor does correctly detect members that are not responding and stops
  routing traffic from the VIP towards the inactive member. Unfortunately the
  traffic that comes in from the floating IP associated with the VIP is not treated
  the same, but is still distributed to the inactive members, resulting in a good
  fraction of the requests to go unanswered. This is tracked in bug
  https://bugs.launchpad.net/neutron/+bug/1956035
* The OCCM always tries to create an HTTP health-monitor. The OVN provider however
  does not yet support HTTP health-monitors, only TCP. We'll have to wait for (and
  possibly help with) HTTP health-monitors to be implemented upstream.

Due to the HTTP health-monitor not being supported, the created loadbalancer is not
considered functional, so the reconciliation loop creates another loadbalancer until
your project runs into quota limits (on the loadbalancer or on ports).
So for now, the feature `use_ovn_lb_provider` should not be enabled.

Note that the `use_ovn_lb_provider` does not affect the LB in front of the kube API.
That one is created by capo and requires other settings. Also note that it would
not yet support the CIDR filtering with `restrict_kubeapi` setting.

# Enabling health-monitor by default?

We could enable a health-monitor by default for load-balancers created from OCCM
in the k8s clusters. This would make services with `externalTrafficPolicy: local`
work, as the traffic would be routed exclusively to active members. But the
other goal would not be achieved: Getting the real client IPs.
We decided against turning on the health-monitor by default, as this might result
in the wrong impression that `local` fully works. Rather break and then have users take
a decision to go for `cluster`, to enable health-monitoring to get it half-working
or to do health-monitoring plus some extra plumbing for proxy protocol (or similar)
to get all aspects working.
