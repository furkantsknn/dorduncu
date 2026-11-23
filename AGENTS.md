# Project change scope

Before completing a behavior or policy change, inspect every connected call site,
screen, admin path, state transition, localization, server authorization path,
and projection that can affect or display it. Reuse one shared server policy for
security-sensitive calculations instead of implementing separate client/admin
versions. In the handoff, classify each discovered surface as updated, unaffected
with a reason, or still missing, and distinguish coded, deployed, and
device-verified work.
