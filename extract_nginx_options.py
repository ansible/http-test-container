import sys

prefix = 'configure arguments: '

for line in sys.stdin:
    if line.startswith(prefix):
        line = line.removeprefix(prefix)
        options = line.split()
        options = [option for option in options if not option.startswith('--add-dynamic-module=')]
        line = ' '.join(options)
        print(line)
        break
else:
    raise Exception()
