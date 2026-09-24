def _channel(value: int) -> float:
    normalized = value / 255
    return normalized / 12.92 if normalized <= 0.04045 else ((normalized + 0.055) / 1.055) ** 2.4


def relative_luminance(hex_color: str) -> float:
    value = hex_color.removeprefix("#")
    if len(value) != 6:
        raise ValueError("Colour must use six hexadecimal digits")
    try:
        red, green, blue = (_channel(int(value[index:index + 2], 16)) for index in (0, 2, 4))
    except ValueError as error:
        raise ValueError("Colour must use six hexadecimal digits") from error
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def contrast_ratio(foreground: str, background: str) -> float:
    lighter, darker = sorted((relative_luminance(foreground), relative_luminance(background)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)
