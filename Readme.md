### Inspired by [GRomR1](https://github.com/GRomR1/docker-slurmbase), Data Driven HPC.

Slurm Version 18.08.3
# Things Included
 - syncronized UID, GID for slurm
 - ansible user.
 - All Slurm RPMs.
 - munged
 - sshd
 - lmod
 - preparation for Lmod & EasyBuild

| Plugins                 | Dependencies     | Built in RPMs |
|------------------------:|:----------------:|--------------:|
| MUNGE                   | `munge-devel`    |    yes        |
| PAM Support             | `pam-devel`      |    yes        |
| cgroup Task Affinity    | `hwloc-devel`    |    yes        |
| IPMI Energy Consumption | `freeimpi-devel` |    no         |
| Lua Support             | `lua-devel`      |    yes        |
| MySql Support           | `mysql-devel`    |    yes        |
