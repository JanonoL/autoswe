# OpenHands 执行器（阶段 4，按需启用）

> 方案文档 §14 阶段 4：编码执行器。OpenHands **以 Docker 镜像运行，不需要源码**——
> 所以本目录只放"如何起服务"，不 vendor 它 27M 的源码。取其精华 = 取它的运行能力。

## 定位

- 输入：spec-kit 产出的 `tasks.md` + 验收用例（Gherkin）。
- 职责：写代码 / 跑测试 / 读失败报告 / 受限重试（执行器，**非裁判**）。
- 裁判：仍由确定性质量门（`speckit-sdlc-gates`：mvn test/契约/扫描）判定，OpenHands 不自评。
- 刹车（与宪法一致）：重试 ≤3、每轮需有进展、超 token/时长预算转人工。

## 启用方式

镜像版本锁定在 `IMAGE_TAG`（见 `.env.example` / `UPSTREAMS.md`）。需要时：

```bash
cd executor
cp .env.example .env          # 按需填 LLM 网关/Key
docker compose up -d
# 打开 http://localhost:3000
```

不需要时不启动即可，对前面 1~3 阶段零影响。

## 更新

改 `UPSTREAMS.md` 里的 OpenHands `IMAGE_TAG` → 重新 `docker compose pull && up -d`。无源码同步成本。
