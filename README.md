# Acadia OS

## Project Description

Acadia-OS is reserved for the Acadia embedded operating-system and board-support deliverables. In the current checkout there is no committed source tree, Yocto layer, kernel configuration, device-tree implementation, boot artifact, service definition, test suite, or executable build target to summarize. The repository directory exists as a planning boundary alongside Acadia-Hardware, Acadia-HAL, Acadia-Client, Acadia-Configuration, Acadia-Server, Acadia-Dashboard, and Acadia-PySDK, but the implementation evidence needed to describe runtime behavior is absent.

The intended responsibility is the software image that boots the Acadia board and provides the platform contract consumed by higher layers: boot configuration, kernel and device-tree support, filesystem/image assembly, system services, networking, update hooks, security posture, and board-specific integration. Those responsibilities must remain hypotheses until files and build metadata are committed. No board processor, co-processor, peripheral mapping, package set, or deployment image should be treated as implemented merely because neighboring repositories mention it.

The useful workflow is repository planning and dependency alignment. Hardware facts should come from Acadia-Hardware once its EDA design is committed; peripheral interfaces should be validated against Acadia-HAL; and service/client assumptions should be coordinated with Configuration and Server. When implementation lands, this README should document image recipes, supported machines, prerequisites, reproducible commands, artifacts, boot/update flow, and test evidence. Until then, every feature below is deliberately marked planned or unknown, and no manual verification is claimed.

## Feature Matrix

| # | Name / Description | Implemented? | Test Coverage? | Manual Test |
|---:|---|---|---|---|
| 1 | Repository boundary and OS ownership | Partial: directory exists; implementation absent | None found | [ ] Manual verification required |
| 2 | Bootloader and boot configuration | Planned | None found | [ ] Manual verification required |
| 3 | Kernel configuration/build | Planned | None found | [ ] Manual verification required |
| 4 | Device tree and board support | Planned | None found | [ ] Manual verification required |
| 5 | Root filesystem/image generation | Planned | None found | [ ] Manual verification required |
| 6 | System services and startup integration | Planned | None found | [ ] Manual verification required |
| 7 | Networking, security, and update integration | Planned | None found | [ ] Manual verification required |
| 8 | Hardware/software contract publication | Unknown | None found | [ ] Manual verification required |
| 9 | Automated OS tests and CI | Unknown | No test files found | [ ] Manual verification required |

## Limitations

This is an evidence-based inventory of an empty implementation surface, not a claim that the planned OS exists. No OS build or test command is currently available.