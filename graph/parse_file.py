import csv

def parse_file(filename, labels):
    def parse_row(row):
        if (len(row) != len(labels)):
            print(f"Bad row: {row} for labels: {labels}")
        assert(len(row) == len(labels))
        ret = dict()
        for elem, label in zip(row, labels):
            ret[label] = elem
        return ret

    with open(filename, newline='') as csvfile:
        spamreader = csv.reader(csvfile, delimiter=',')

        parsed = list(map(parse_row, spamreader))
        return parsed

def parse_file_dict(filename, labels):
    ret = dict()
    def parse_row(row):
        if len(row) - 1 != len(labels):
            print(row)
            print(labels)
        assert(len(row) - 1 == len(labels))
        datum = dict()
        for elem, label in zip(row[1:], labels):
            datum[label] = elem
        ret[row[0]] = datum

    with open(filename, newline='') as csvfile:
        spamreader = csv.reader(csvfile, delimiter=',')

        parsed = list(map(parse_row, spamreader))
        return ret
