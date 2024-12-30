# Ed Callaghan
# Make life easy
# December 2024

SRC	= diagram.dot
CMD = dot
FMT = png
OUT	= $(SRC).$(FMT)

draw: $(SRC)
	$(CMD) -T$(FMT) $^ >$(OUT)

view: draw
	eog $(OUT)

clean:
	-rm -f $(OUT)

.PHONY: clean
