# Open Source Release Checklist

Use this checklist before pushing the repository to GitHub.

## Required

- Confirm no kubeconfig, token, password, or internal endpoint remains in tracked files.
- Confirm all default image references are either public images or local example tags.
- Confirm namespace, storage class, and NodePort defaults match the target environment.
- Confirm README examples still match the current manifests and helper scripts.
- Confirm .env is ignored and only .env.example is committed.
- Confirm the selected license matches how you intend others to use the project.

## Recommended

- Test deployment on a clean cluster using only the files in this repository.
- Verify the local-image flow works without pushing to a registry.
- Replace NodePort with Ingress or LoadBalancer if that better matches your users.
- Pin image versions after the deployment is stable.
- Add screenshots if you want the GitHub page to be easier to scan.

## Final check commands

```bash
rg -n "namespace:|image:|storageClassName:|nodePort:" *.yaml
```
