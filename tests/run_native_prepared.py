from pathlib import Path
import argparse,os,subprocess,zipfile
p=argparse.ArgumentParser();p.add_argument('--engine',type=Path,required=True);p.add_argument('--imports',type=Path,required=True);p.add_argument('--love',type=Path,required=True);p.add_argument('--work',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1];engine=a.engine.resolve();work=a.work.resolve();work.mkdir(parents=True,exist_ok=True);app=work/'native-prepared.love'
with zipfile.ZipFile(app,'w',zipfile.ZIP_DEFLATED)as z:
 for d in ('src','data','assets'):
  for f in (engine/d).rglob('*'):
   if f.is_file():z.write(f,f.relative_to(engine))
 z.write(root/'tests/native_prepared_love.lua','main.lua');z.writestr('conf.lua',"function love.conf(t)t.identity='hoennto_prepared_test';t.window.width=240;t.window.height=160;t.modules.joystick=false end")
env=dict(os.environ,HOENNTO_PROJECT=str(root),HOENNTO_ENGINE=str(engine),HOENNTO_IMPORTS=str(a.imports.resolve()),XDG_DATA_HOME=str(work/'userdata'),SDL_VIDEODRIVER='offscreen',ALSOFT_DRIVERS='null')
raise SystemExit(subprocess.run([str(a.love.resolve()),str(app)],env=env).returncode)
