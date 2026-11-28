# FlareUI public API

What other addons can rely on. Each part has a version number. Within a version we only add
fields; we never remove or change one. A change that would break an addon gets a new version,
and the old one keeps working for at least one major FlareUI release.

Ask for more in a GitHub issue. Please tell us what your addon needs, not how to build it.

## Quest tracker rows: `FlareUI_QuestTrackerAPI` (version 1)

Put a button of your own beside a quest's row in FlareUI's quest tracker, the way the tracker
places its quest item buttons. FlareUI only tells you where. You make, show, hide and secure your
buttons yourself.

```lua
local api = FlareUI_QuestTrackerAPI
if api and api.version >= 1 then
    api:RegisterCallback("MyAddon", function(rows)
        -- hide all your buttons first: a quest missing from rows has no row now
        for _, row in ipairs(rows) do
            local b = MyButtonFor(row.questID)
            b:SetSize(row.size, row.size)
            b:ClearAllPoints()
            b:SetPoint(row.point, UIParent, "BOTTOMLEFT", row.x, row.y)
            b:Show()
        end
    end)
end
```

| Function | What it does |
|---|---|
| `api:RegisterCallback(owner, callback)` | `callback(rows)` runs each time the tracker places its rows. One callback per `owner` (any value of yours). |
| `api:UnregisterCallback(owner)` | Stops it. |
| `api:GetRows()` | The rows as last placed. |
| `api:IsActive()` | `true` while FlareUI's tracker is on and showing. |

Each row:

| Field | Meaning |
|---|---|
| `questID` | The quest. |
| `point`, `x`, `y` | Where your button's corner goes: `SetPoint(point, UIParent, "BOTTOMLEFT", x, y)`. The spot is outside the tracker, on the side its item buttons use, already past the quest's own item button. |
| `size` | The item buttons' size: use it for yours. |
| `hasItem` | The quest has its own item button beside it. |
| `line` | The row's frame. Read it only: don't move, hide or hook it. |

When it runs:
- After every redraw, scroll, collapse, sort or resize, out of a fight only. Our item buttons are
  protected and can't move in a fight, and yours can't either.
- With an empty list when the tracker hides, is minimized or nothing is in view.
- Only rows fully in view are listed. Quests scrolled out of sight are left out.

Don't change the `rows` table, or what is in it. It is reused for the next call.
