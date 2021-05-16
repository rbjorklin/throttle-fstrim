throttle-fstrim
===============

.. contents::


Why would I need this?
======================

Running ``fstrim`` on a volume pretty much exhausts an SSDs write capacity.
This allows you to keep using the drive at only a slightly reduced performance but
the ``fstrim`` process will run for much longer as a consequence.
There is a `great article over at Ars Technica`_ detailing why you may see
significant improvements in performance predictibility even on expensive enterprise SSDs.

.. _great article over at Ars Technica: https://arstechnica.com/gadgets/2015/04/ask-ars-my-ssd-does-garbage-collection-so-i-dont-need-trim-right/
