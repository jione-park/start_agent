# start_agent

`zsh`, `oh-my-zsh`, Codex CLI, 자동완성/히스토리 설정, `tmux`, TPM, 기본 `tmux.conf` 적용을 한 번에 처리하는 스크립트 저장소다.

## 구조

- `install.sh`: 전체 설치 엔트리포인트
- `scripts/install-shell.sh`: `zsh`, `oh-my-zsh`, zsh plugin, Codex CLI, `.zshrc` 설정
- `scripts/install-tmux.sh`: `tmux`, TPM, tmux plugin 설치, `tmux.conf` 반영
- `lib/common.sh`: 공통 유틸 함수
- `tmux.conf`: `~/.tmux.conf`로 복사되는 기본 tmux 설정

## 사용법

```bash
chmod +x install.sh scripts/install-shell.sh scripts/install-tmux.sh
./install.sh
```

개별 실행도 가능하다.

```bash
./scripts/install-shell.sh
./scripts/install-tmux.sh
```

설치 전에 변경 없이 확인만 하려면 다음 모드를 사용한다.

```bash
./install.sh --dry-run
./install.sh --check
```

- `--dry-run`: 실제 설치, clone, `chsh`, 파일 복사 없이 예정 작업만 출력
- `--check`: 패키지 매니저, 필수 명령, 네트워크, npm registry 접근, 쓰기 가능 경로, `tmux.conf` 배치 상태를 점검

## tmux.conf 반영 방식

레포지토리 루트에 `tmux.conf`를 추가하면 `scripts/install-tmux.sh`가 이를 `~/.tmux.conf`로 복사한다. 이미 tmux 세션 안에서 실행 중이면 `tmux source-file ~/.tmux.conf`까지 수행하고, TPM이 있으면 `install_plugins`로 플러그인도 자동 설치한다.

현재 기본 `tmux.conf`에는 아래 플러그인이 선언되어 있다.

- `tmux-plugins/tpm`
- `dracula/tmux`
- `tmux-plugins/tmux-sensible`
- `sainnhe/tmux-fzf`
- `tmux-plugins/tmux-resurrect`
- `tmux-plugins/tmux-continuum`
- `NHDaly/tmux-better-mouse-mode`

## 주의

- 패키지 설치는 `brew` 또는 `apt-get` 기준으로 처리한다.
- `oh-my-zsh`, git clone, `npm install -g @openai/codex` 단계는 네트워크가 필요하다.
- 기본 쉘 변경 시 `chsh`가 비밀번호를 요구할 수 있다.
- Codex CLI 설치 후에는 `codex login` 또는 `OPENAI_API_KEY` 설정이 필요할 수 있다.
