## 10. Why this shape (design notes)

The reasoning under these decisions is in part two of
[`APPENDIX.md`](APPENDIX.md): why the bus is committed files and not a
side channel, why every file has exactly one writer, why the master
adjudicates instead of voting, and why the liveness stack exists at all.
Read it before you change the protocol, so you know what a change costs.

One line of it belongs here rather than there, because it decides how
you test. REVIEWING THE PROTOCOL AND REVIEWING A RUN OF IT FIND
DIFFERENT THINGS, and neither substitutes for the other. Reading these
files finds what is missing, contradictory or unclear in them. Operating
them finds what they never anticipated. Most of the rules here came from
the second kind.
