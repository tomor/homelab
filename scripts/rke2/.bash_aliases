export PATH="$PATH:/var/lib/rancher/rke2/bin"

if [ -f /etc/rancher/rke2/rke2.yaml ]; then
  export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
fi

alias k=kubectl
alias kg='kubectl get'
alias kd='kubectl describe'
alias ll='ls -alF'
