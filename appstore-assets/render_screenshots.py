from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).parent
OUT = ROOT / "output"
OUT.mkdir(exist_ok=True)
W, H = 1242, 2688
BOLD = "/Users/kim-eunchan/Library/Fonts/NanumSquareB.otf"
REGULAR = "/Users/kim-eunchan/Library/Fonts/NanumSquareR.otf"

cards = [
    ("01-pacing-intro", "source/hero.jpg", "RUN WITH THE SAME RHYTHM", ("같은 음악,", "같은 페이스"), "음악으로 연결되는 새로운 러닝 경험", "#FFFFFF", True),
    ("02-running-overview", "source/home.png", "MY RUNNING", ("오늘의 러닝을", "한눈에"), "거리, 시간, 페이스까지 나만의 기록을 확인하세요", "#FF2D55", False),
    ("03-run-with-map", "source/running.png", "RUN WITH PACING", ("달리는 순간을", "기록하세요"), "지도 위에서 나의 경로와 페이스를 남겨보세요", "#A73BE2", False),
    ("04-music", "source/music.png", "MUSIC FOR RUNNING", ("나만의 리듬으로", "더 멀리"), "러닝에 어울리는 음악과 함께 달려보세요", "#FF2D55", False),
    ("05-listen-together", "source/listen-together.png", "LISTEN TOGETHER", ("같은 음악으로", "함께 달려요"), "주변 러너와 실시간으로 음악을 같이 들어보세요", "#8A3BDA", False),
    ("06-activity-detail", "source/record.png", "RUN ANALYTICS", ("나의 기록이", "쌓이는 즐거움"), "거리, 시간, 경로를 되돌아보며 다음 러닝을 준비하세요", "#FF2D55", False),
    ("07-friends", "source/friends.png", "RUNNING MATES", ("음악 취향으로", "연결되는 러너들"), "친구를 찾고 함께할 러닝 메이트를 만나보세요", "#9D42DF", False),
    ("08-playlists", "source/playlists.png", "DISCOVER PLAYLISTS", ("새로운 음악으로", "새로운 러닝"), "러너들의 플레이리스트를 발견하고 바로 들어보세요", "#FF2D55", False),
]

def font(path, size):
    return ImageFont.truetype(path, size)

def color(hex_color, alpha=255):
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4)) + (alpha,)

def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *size), radius, fill=255)
    return mask

def centered_text(draw, xy, text, fnt, fill, spacing=4):
    draw.text(xy, text, font=fnt, fill=fill, anchor="mm", spacing=spacing)

def pastel_background(accent):
    canvas = Image.new("RGBA", (W, H), "#fff9fb")
    px = canvas.load()
    top = (255, 247, 250)
    bottom = (249, 242, 255)
    for y in range(H):
        t = y / (H - 1)
        c = tuple(int(top[i] * (1-t) + bottom[i] * t) for i in range(3))
        for x in range(W):
            px[x, y] = (*c, 255)
    # soft brand glows
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    a = color(accent, 42)
    gd.ellipse((730, -170, 1510, 610), fill=a)
    gd.ellipse((-430, 2180, 480, 3090), fill=a)
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    return Image.alpha_composite(canvas, glow)

def add_device(canvas, source):
    x, y, iw, ih = 154, 664, 934, 1958
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x+10, y+28, x+iw+10, y+ih+28), 118, fill=(30, 10, 23, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas.alpha_composite(shadow)
    device = Image.new("RGBA", (iw, ih), (24, 21, 25, 255))
    screen = Image.open(source).convert("RGBA").resize((872, 1896), Image.Resampling.LANCZOS)
    screen_mask = rounded_mask((872, 1896), 84)
    device.paste(screen, (31, 31), screen_mask)
    canvas.paste(device, (x, y), rounded_mask((iw, ih), 115))

for name, source, eyebrow, title, body, accent, hero in cards:
    if hero:
        image = Image.open(ROOT / source).convert("RGBA").resize((W, H), Image.Resampling.LANCZOS)
        shade = Image.new("RGBA", (W, H), (28, 0, 23, 0))
        sh = ImageDraw.Draw(shade)
        sh.rectangle((0, 0, W, 830), fill=(25, 0, 25, 74))
        sh.rectangle((0, 2160, W, H), fill=(20, 0, 32, 58))
        image = Image.alpha_composite(image, shade)
        draw = ImageDraw.Draw(image)
        draw.rounded_rectangle((72, 124, 308, 180), 28, fill=(255,255,255,42))
        centered_text(draw, (190, 153), "PACING", font(BOLD, 25), "#FF2D55")
        draw.text((80, 316), eyebrow, font=font(BOLD, 29), fill="white")
        draw.text((80, 440), title[0], font=font(BOLD, 90), fill="white")
        draw.text((80, 546), title[1], font=font(BOLD, 90), fill="white")
        draw.text((82, 680), body, font=font(REGULAR, 33), fill=(255,255,255,235))
        centered_text(draw, (W//2, 2495), "RUN. LISTEN. CONNECT.", font(BOLD, 27), (255,255,255,210))
    else:
        image = pastel_background(accent)
        draw = ImageDraw.Draw(image)
        draw.text((80, 148), eyebrow, font=font(BOLD, 28), fill=color(accent))
        draw.text((80, 294), title[0], font=font(BOLD, 84), fill="#171116")
        draw.text((80, 400), title[1], font=font(BOLD, 84), fill="#171116")
        draw.text((82, 542), body, font=font(REGULAR, 32), fill="#60545b")
        add_device(image, ROOT / source)
        draw = ImageDraw.Draw(image)
        centered_text(draw, (W//2, 2640), "PACING", font(BOLD, 24), "#907f88")
    image.convert("RGB").save(OUT / f"{name}.png", quality=100)
