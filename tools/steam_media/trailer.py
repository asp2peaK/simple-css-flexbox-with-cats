import subprocess, sys, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
S=os.environ.get('MEDIA','/tmp/gs/media')  # клипы лежат в $MEDIA/clips/<сцена>_<язык>
lang=sys.argv[1]; out=sys.argv[2]
FONT=ROOT+'/fonts/DejaVuSans-Bold.ttf'
T={'en':[('card','You run a parcel pickup point...'),('clip','counter',6),
 ('card','...for witches, orcs and skeletons'),('clip','warehouse',4),
 ('card','Spot the scammers'),('clip','scam',4),
 ('card','Handle returns. No muddy boxes!'),('clip','returns',4),
 ('card','Play co-op with friends'),('clip','coop',4),
 ('card','Pet the cat. Carefully.'),('clip','cat',4),
 ('card','Floods! Rats! Inspectors!'),('clip','flood',4),
 ('card','Letters from your dragon boss'),('clip','letter',4),
 ('card','Survive Chaos Mode'),('clip','chaos',4),
 ('card','Decorate your shop'),('clip','decor',4),
 ('card','Dress up in the magic mirror'),('clip','mirror',6),
 ('card','Beware the Dark Postmaster'),('clip','boss',6),
 ('end','NOT MY PARCEL!','Wishlist now on Steam')],
 'ru':[('card','Ты работаешь в пункте выдачи...'),('clip','counter',6),
 ('card','...для ведьм, орков и скелетов'),('clip','warehouse',4),
 ('card','Лови мошенников'),('clip','scam',4),
 ('card','Принимай возвраты. Грязные не бери!'),('clip','returns',4),
 ('card','Играй вместе с друзьями'),('clip','coop',4),
 ('card','Гладь кота. Осторожно.'),('clip','cat',4),
 ('card','Потопы! Крысы! Инспекторы!'),('clip','flood',4),
 ('card','Письма от босса-дракона'),('clip','letter',4),
 ('card','Выживи в режиме хаоса'),('clip','chaos',4),
 ('card','Укрась свой пункт'),('clip','decor',4),
 ('card','Наряжайся у волшебного зеркала'),('clip','mirror',6),
 ('card','Берегись Тёмного Почтмейстера'),('clip','boss',6),
 ('end','NOT MY PARCEL!','Добавь в желаемое в Steam')]}[lang]
W,H=1280,720; FPS=30
tmp=f'{S}/tr_{lang}'; os.makedirs(tmp,exist_ok=True)
def bg_from(clip):
    d=f'{S}/clips/{clip}_{lang}'
    fr=sorted(os.listdir(d)); im=Image.open(f'{d}/{fr[len(fr)//2]}').convert('RGB').resize((W,H))
    im=im.filter(ImageFilter.GaussianBlur(14))
    return Image.blend(im,Image.new('RGB',(W,H),(20,12,8)),0.6)
def text(im,s,size,y,col=(255,200,90)):
    d=ImageDraw.Draw(im); f=ImageFont.truetype(FONT,size)
    w=d.textlength(s,font=f); d.text(((W-w)/2,y),s,font=f,fill=col,stroke_width=max(3,size//14),stroke_fill=(30,15,40))
segs=[]
for i,it in enumerate(T):
    seg=f'{tmp}/s{i:02d}.mp4'
    if it[0]=='clip':
        d=f'{S}/clips/{it[1]}_{lang}'; dur=it[2]
        cmd=['ffmpeg','-y','-v','error','-framerate',str(FPS),'-i',f'{d}/f_%05d.png','-t',str(dur),
             '-vf',f'scale={W}:{H}:flags=lanczos,fade=t=in:st=0:d=0.25,fade=t=out:st={dur-0.25}:d=0.25,format=yuv420p','-r',str(FPS),'-c:v','libx264','-crf','18','-preset','medium',seg]
    else:
        nxt=next((x[1] for x in T[i+1:] if x[0]=='clip'),'boss')
        im=bg_from(nxt if it[0]=='card' else 'counter')
        if it[0]=='card':
            text(im,it[1],52,H//2-34); dur=2.0
        else:
            text(im,it[1],110,H//2-110,(255,170,60)); text(im,it[2],44,H//2+50,(255,255,255)); text(im,"2peaK's Studio",28,H-70,(200,190,180)); dur=4.0
        p=f'{tmp}/c{i:02d}.png'; im.save(p)
        cmd=['ffmpeg','-y','-v','error','-loop','1','-framerate',str(FPS),'-i',p,'-t',str(dur),
             '-vf',f'fade=t=in:st=0:d=0.3,fade=t=out:st={dur-0.3}:d=0.3,format=yuv420p','-r',str(FPS),'-c:v','libx264','-crf','18',seg]
    subprocess.run(cmd,check=True); segs.append(seg)
open(f'{tmp}/list.txt','w').write(''.join(f"file '{s}'\n" for s in segs))
subprocess.run(['ffmpeg','-y','-v','error','-f','concat','-safe','0','-i',f'{tmp}/list.txt','-c','copy',f'{tmp}/video.mp4'],check=True)
dur=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',f'{tmp}/video.mp4']))
# своя музыка трейлера: tools/synth_trailer_music.py (такт = 2 с, разделы совпадают с монтажом)
mus=f'{tmp}/trailer_music.wav'
subprocess.run([sys.executable,ROOT+'/tools/synth_trailer_music.py',mus],check=True)
subprocess.run(['ffmpeg','-y','-v','error','-i',mus,'-af',f'atrim=0:{dur},afade=t=out:st={dur-1.5}:d=1.5','-c:a','aac','-b:a','192k',f'{tmp}/music.m4a'],check=True)
subprocess.run(['ffmpeg','-y','-v','error','-i',f'{tmp}/video.mp4','-i',f'{tmp}/music.m4a','-c:v','copy','-c:a','copy','-shortest','-movflags','+faststart',out],check=True)
print(out, round(dur,1),'s')
