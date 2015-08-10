Passphrase Maker

This makes memorable and very random passphrases (very varying on how many words you have in /usr/share/dict/words). It reports the entropy to you too, if I calculated that right. `log2(amount of possible states)`

Build this with “nimble build” in this directory.

Options passed as environment variables. Say “sep=' '” for space separated, plus some punctuation thrown in there to add moar entropy, or “sep='-'” for dash separated, sans punctuation. Or just leave as-is for a sequence of words CamelCased.

Say “num=10” to pull 10 words out of the database. Words may repeat, but that’s good because it means more possible passphrases.

https://xkcd.com/936/
