# Deploying qem-dashboard inside containers on MicroOS

## A quick start guide

1. `mkdir -p /var/lib/data/qem/psql-data && cd /var/lib/data/qem`
2. `git clone https://github.com/openSUSE/qem-dashboard.git`
3. `sed -i -e 's#pg: .*#pg: postgresql://postgres@localhost:5432/postgres#' qem-dashboard/dashboard.yml`
4. `for quadlet in qem-dashboard/containers/systemd/*; do ln -s "$PWD/$quadlet" /etc/containers/systemd/; done`
5. `systemctl daemon-reload && systemctl start qem-pod`

After `podman build` completes, new container is spawned inside the pod and the qem-dashboard will be available on port 3000.
