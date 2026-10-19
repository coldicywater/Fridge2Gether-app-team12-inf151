import { useEffect, useState } from "react";

type Screen = "home" | "category" | "shared" | "recipes" | "camera" | "details";
type Category = "personal" | "shared" | "expiring";
type UserProfile = {
  name: string;
  household: "alone" | "roommates";
  roommates: string[];
};
type Quantity = { amount: number; unit: string };
type Food = {
  id: string;
  name: string;
  image: string;
  freshness: "fresh" | "soon" | "urgent";
  date: string;
  days: string;
  quantity: string;
  countable: boolean;
  unit: string;
  amount: number;
};

const photos = {
  ingredients:
    "https://images.unsplash.com/photo-1779958128621-c933204c0ed0?auto=format&fit=crop&w=500&q=85",
  produce:
    "https://images.unsplash.com/photo-1641301547846-2cf73f58fdca?auto=format&fit=crop&w=500&q=85",
  cucumber:
    "https://images.unsplash.com/photo-1611255154124-ef4f572703ca?auto=format&fit=crop&w=500&q=85",
  pear:
    "https://images.unsplash.com/photo-1664568218050-8068915c3b40?auto=format&fit=crop&w=500&q=85",
  pasta:
    "https://images.unsplash.com/photo-1608897013039-887f21d8c804?auto=format&fit=crop&w=800&q=85",
  toast:
    "https://images.unsplash.com/photo-1670842587871-326b95acbc8c?auto=format&fit=crop&w=800&q=85",
  salad:
    "https://images.unsplash.com/photo-1617474019977-0e105d1b430e?auto=format&fit=crop&w=800&q=85",
};

const foods: Food[] = [
  {
    id: "milk",
    name: "Oat milk",
    image: photos.ingredients,
    freshness: "urgent",
    date: "May 25",
    days: "1 day left",
    quantity: "About half",
    countable: false,
    unit: "ml",
    amount: 500,
  },
  {
    id: "avocado",
    name: "Avocado",
    image: photos.ingredients,
    freshness: "soon",
    date: "May 27",
    days: "3 days left",
    quantity: "2 pieces",
    countable: true,
    unit: "pieces",
    amount: 2,
  },
  {
    id: "veg",
    name: "Fresh veggies",
    image: photos.produce,
    freshness: "fresh",
    date: "Jun 1",
    days: "8 days left",
    quantity: "1 basket",
    countable: true,
    unit: "basket",
    amount: 1,
  },
  {
    id: "cucumber",
    name: "Cucumber",
    image: photos.cucumber,
    freshness: "soon",
    date: "May 26",
    days: "2 days left",
    quantity: "Half",
    countable: false,
    unit: "g",
    amount: 180,
  },
  {
    id: "pear",
    name: "Pear",
    image: photos.pear,
    freshness: "fresh",
    date: "May 30",
    days: "6 days left",
    quantity: "3 pieces",
    countable: true,
    unit: "pieces",
    amount: 3,
  },
];

function Icon({
  name,
  size = 24,
  strokeWidth = 2,
}: {
  name: "users" | "fridge" | "chef" | "plus" | "back" | "lock" | "clock" | "sparkle" | "camera";
  size?: number;
  strokeWidth?: number;
}) {
  const paths: Record<string, React.ReactNode> = {
    users: (
      <>
        <circle cx="9" cy="8" r="3" />
        <path d="M3.8 19c.6-3.2 2.4-5 5.2-5s4.6 1.8 5.2 5M15 5.5a3 3 0 0 1 0 5.8M16.5 14c2.1.4 3.4 2 3.7 4.4" />
      </>
    ),
    fridge: (
      <>
        <rect x="6" y="2.5" width="12" height="19" rx="2.5" />
        <path d="M6 10h12M9 6.5v1.7M9 13.5v2.2M8 21.5v1M16 21.5v1" />
      </>
    ),
    chef: (
      <>
        <path d="M7.2 10a4 4 0 1 1 2.2-7.2A4.4 4.4 0 0 1 17 5.5a3.3 3.3 0 0 1-.3 6.5H7.2a3.2 3.2 0 0 1 0-6.4" />
        <path d="M7 12v7.5c2.9 1.3 7.1 1.3 10 0V12M9.5 17h5" />
      </>
    ),
    plus: <path d="M12 5v14M5 12h14" />,
    back: <path d="m15 18-6-6 6-6" />,
    lock: (
      <>
        <rect x="5" y="10" width="14" height="11" rx="3" />
        <path d="M8 10V7a4 4 0 0 1 8 0v3" />
      </>
    ),
    clock: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v5l3 2" />
      </>
    ),
    sparkle: <path d="m12 2 1.4 5.2L18 10l-4.6 2.8L12 18l-1.4-5.2L6 10l4.6-2.8L12 2ZM19 17l.6 2.2L22 20.5l-2.4 1.3L19 24l-.6-2.2-2.4-1.3 2.4-1.3L19 17Z" />,
    camera: (
      <>
        <path d="M4 8.5h3l1.5-2h7l1.5 2h3v11H4z" />
        <circle cx="12" cy="14" r="3.5" />
      </>
    ),
  };
  return (
    <svg
      aria-hidden="true"
      fill="none"
      height={size}
      viewBox="0 0 24 24"
      width={size}
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={strokeWidth}
    >
      {paths[name]}
    </svg>
  );
}

function Sticker({
  food,
  small = false,
  muted = false,
  highlighted = false,
  sharedBy,
  onClick,
}: {
  food: Food;
  small?: boolean;
  muted?: boolean;
  highlighted?: boolean;
  sharedBy?: string;
  onClick?: () => void;
}) {
  const className = `sticker sticker-${food.freshness} ${small ? "sticker-small" : ""} ${muted ? "sticker-muted" : ""} ${highlighted ? "sticker-shared-new" : ""}`;
  const content = (
    <>
      <img alt={food.name} src={food.image} />
      <span>{food.name}</span>
      {sharedBy && <b className="shared-by-badge">{sharedBy[0]?.toUpperCase()}</b>}
    </>
  );

  if (!onClick) {
    return <div className={className}>{content}</div>;
  }

  return (
    <button aria-label={`Open ${food.name}`} className={className} onClick={onClick} type="button">
      {content}
    </button>
  );
}

function Fridge({
  shared = false,
  onFood,
  sharedFoodIds = [],
  activeFoodIds = foods.map((food) => food.id),
  highlightedFoodIds = [],
  owners = {},
  currentUser,
  onOpenCategory,
}: {
  shared?: boolean;
  onFood?: (food: Food) => void;
  sharedFoodIds?: string[];
  activeFoodIds?: string[];
  highlightedFoodIds?: string[];
  owners?: Record<string, string>;
  currentUser?: string;
  onOpenCategory?: (category: Category) => void;
}) {
  if (!shared) {
    const sharedIds = new Set(sharedFoodIds);
    const availableFoods = foods.filter((food) => activeFoodIds.includes(food.id));
    const personalFoods = availableFoods.filter((food) => food.freshness === "fresh" && !sharedIds.has(food.id));
    const sharedFoods = availableFoods.filter((food) => food.freshness === "fresh" && sharedIds.has(food.id));
    const expiringFoods = availableFoods.filter((food) => food.freshness !== "fresh");

    return (
      <div className="fridge status-fridge">
        <section className="status-zone personal-zone" onClick={(event) => {
          if ((event.target as HTMLElement).closest(".sticker")) return;
          onOpenCategory?.("personal");
        }}>
          <div className="zone-label"><span>Personal</span><small>just yours</small></div>
          <div className="zone-foods">
            {personalFoods.map((food) => <Sticker food={food} highlighted={highlightedFoodIds.includes(food.id)} key={food.id} onClick={() => onFood?.(food)} />)}
          </div>
        </section>
        <section className="status-zone shared-zone" onClick={(event) => {
          if ((event.target as HTMLElement).closest(".sticker")) return;
          onOpenCategory?.("shared");
        }}>
          <div className="zone-label"><span>Shared</span><small>roommates can use</small></div>
          <div className="zone-foods">
            {sharedFoods.map((food) => {
              const owner = owners[food.id];
              return <Sticker food={food} highlighted={highlightedFoodIds.includes(food.id)} sharedBy={owner && owner !== currentUser ? owner : undefined} key={food.id} onClick={() => onFood?.(food)} />;
            })}
          </div>
        </section>
        <section className="status-zone expiring-zone" onClick={(event) => {
          if ((event.target as HTMLElement).closest(".sticker")) return;
          onOpenCategory?.("expiring");
        }}>
          <div className="zone-label"><span>Almost Expired</span><small>use these soon</small></div>
          <div className="zone-foods">
            {expiringFoods.map((food) => <Sticker food={food} highlighted={highlightedFoodIds.includes(food.id)} key={food.id} onClick={() => onFood?.(food)} />)}
          </div>
        </section>
        <div className="fridge-leg left" />
        <div className="fridge-leg right" />
      </div>
    );
  }

  return (
    <div className="fridge">
      <div className="freezer">
        <div className="snowflake">✳</div>
        <Sticker food={foods[4]} small onClick={() => onFood?.(foods[4])} />
        <div className="icebox">ICE</div>
      </div>
      <div className="shelf shelf-one">
        <div className="shared-item">
          <Sticker food={foods[0]} onClick={() => onFood?.(foods[0])} />
          <b>OK to use</b>
        </div>
        <div className="private-item">
          <Sticker food={foods[1]} muted />
          <span className="owner">A</span>
          <span className="mini-lock"><Icon name="lock" size={11} /></span>
        </div>
      </div>
      <div className="shelf shelf-two">
        <Sticker food={foods[2]} onClick={() => onFood?.(foods[2])} />
        <Sticker food={foods[3]} onClick={() => onFood?.(foods[3])} />
      </div>
      <div className="crisper">
        <span>fresh stuff</span>
        <div className="crisper-foods">
          <Sticker food={foods[3]} small onClick={() => onFood?.(foods[3])} />
          <Sticker food={foods[4]} small onClick={() => onFood?.(foods[4])} />
        </div>
      </div>
      <div className="fridge-leg left" />
      <div className="fridge-leg right" />
    </div>
  );
}

function Header({ title, subtitle, userName, onProfile }: { title: string; subtitle?: string; userName: string; onProfile: () => void }) {
  const safeName = typeof userName === "string" && userName.trim() ? userName.trim() : "You";
  const initials = safeName.split(/\s+/).map((part) => part[0]).join("").slice(0, 2).toUpperCase();
  return (
    <header className="topbar">
      <div>
        <p className="eyebrow">{subtitle}</p>
        <h1>{title}</h1>
      </div>
      <button className="avatar" aria-label="Edit profile and roommates" onClick={onProfile} type="button">
        <span>{initials}</span>
        <i />
      </button>
    </header>
  );
}

function BottomNav({ screen, setScreen }: { screen: Screen; setScreen: (screen: Screen) => void }) {
  return (
    <nav className="bottom-nav" aria-label="Main navigation">
      <button className={screen === "home" || screen === "category" ? "active" : ""} onClick={() => setScreen("home")} type="button">
        <Icon name="fridge" />
        <span>Fridge</span>
      </button>
      <button
        className="nav-main"
        aria-label="Scan groceries"
        onClick={() => setScreen("camera")}
        type="button"
      >
        <Icon name="camera" size={28} strokeWidth={2.2} />
      </button>
      <button className={screen === "recipes" ? "active" : ""} onClick={() => setScreen("recipes")} type="button">
        <Icon name="chef" />
        <span>Recipes</span>
      </button>
    </nav>
  );
}

const portionOptions = [
  { label: "Empty", value: 0 },
  { label: "¼ Full", value: 0.25 },
  { label: "½ Full", value: 0.5 },
  { label: "¾ Full", value: 0.75 },
  { label: "Full", value: 1 },
];

function PortionSelector({ value, onChange, compact = false }: { value: number; onChange: (value: number) => void; compact?: boolean }) {
  return (
    <div className={`portion-selector ${compact ? "compact" : ""}`} aria-label="Amount remaining">
      {portionOptions.map((portion) => (
        <button className={value === portion.value ? "selected" : ""} onClick={() => onChange(portion.value)} type="button" key={portion.label}>
          <span className="portion-cup"><i style={{ height: `${portion.value * 100}%` }} /></span>
          <small>{portion.label}</small>
        </button>
      ))}
    </div>
  );
}

function DetailSheet({
  food,
  close,
  openRecipes,
  isShared,
  onSharingChanged,
  roommates,
  owner,
  savedQuantity,
  onQuantityChanged,
  onUsedUp,
  onOffer,
  sharedByRoommate,
  sharedWith,
}: {
  food: Food;
  close: () => void;
  openRecipes: () => void;
  isShared: boolean;
  onSharingChanged: (foodId: string, shared: boolean) => void;
  roommates: string[];
  owner: string;
  savedQuantity: Quantity;
  onQuantityChanged: (foodId: string, quantity: Quantity) => void;
  onUsedUp: (foodId: string) => void;
  onOffer: (food: Food, recipients: string[]) => void;
  sharedByRoommate: boolean;
  sharedWith: string[];
}) {
  const [quantity, setQuantity] = useState(savedQuantity);
  const [panel, setPanel] = useState<"main" | "quantity" | "share" | "rescue" | "usedUp">("main");
  const [sharing, setSharing] = useState<"Just Me" | "Everyone" | "Selected Roommates">(
    isShared ? (sharedWith.length > 0 && sharedWith.length < roommates.length ? "Selected Roommates" : "Everyone") : "Just Me",
  );
  const [selectedRoommates, setSelectedRoommates] = useState(sharedWith.length > 0 ? sharedWith : roommates.slice(0, 1));
  const [portion, setPortion] = useState(Math.max(0, Math.min(1, quantity.amount / food.amount)));
  const quantityLabel = `${quantity.amount} ${quantity.unit}`;
  const isAlmostExpired = food.freshness !== "fresh";

  const toggleRoommate = (name: string) => {
    setSelectedRoommates((current) =>
      current.includes(name) ? current.filter((roommate) => roommate !== name) : [...current, name],
    );
  };

  return (
    <div className="sheet-backdrop" onClick={close}>
      <section className="detail-sheet" onClick={(event) => event.stopPropagation()} aria-label={`${food.name} details`}>
        <div className="sheet-handle" />
        <div className="detail-hero">
          <Sticker food={food} />
          <div>
            <span className={`freshness-pill ${food.freshness}`}>{food.days}</span>
            <h2>{food.name}</h2>
            <p>Best before {food.date}</p>
          </div>
        </div>
        <div className="detail-grid">
          <div><small>Quantity</small><strong>{quantityLabel}</strong></div>
          <div><small>Expires</small><strong>{food.date} · {food.days}</strong></div>
          <div><small>Owner</small><strong>{owner}</strong></div>
          <div><small>Sharing</small><strong>{sharedByRoommate ? "Shared with you" : sharing === "Selected Roommates" ? selectedRoommates.join(", ") : sharing}</strong></div>
        </div>
        {panel === "main" && (
          <>
            {food.freshness !== "fresh" && !isAlmostExpired && (
              <div className="use-soon-actions">
                <p>Use soon</p>
                <div>
                  <button onClick={openRecipes} type="button">What can I make?</button>
                </div>
              </div>
            )}
            <div className={`sheet-actions ${isAlmostExpired ? "three-actions" : ""}`}>
              <button className="secondary" onClick={() => setPanel("quantity")} type="button">I Used Some</button>
              <button className="secondary used-up" onClick={() => {
                if (isAlmostExpired) setPanel("usedUp");
                else {
                  onUsedUp(food.id);
                  close();
                }
              }} type="button">Used Up</button>
              {!sharedByRoommate && <button className={`share-action ${isAlmostExpired ? "almost-expired-share" : ""}`} onClick={() => {
                if (isAlmostExpired) {
                  setSharing("Selected Roommates");
                  setPanel("rescue");
                } else {
                  setPanel("share");
                }
              }} type="button">
                <Icon name="users" size={19} /> {isAlmostExpired ? "Share it with..." : "Change sharing"}
              </button>}
            </div>
          </>
        )}
        {panel === "quantity" && (
          <div className="inline-panel">
            <div className="panel-heading"><strong>How much is left?</strong><span>Select the remaining level</span></div>
            <PortionSelector value={portion} onChange={setPortion} />
            <button className="primary portion-save" onClick={() => {
              const nextQuantity = { ...quantity, amount: Math.round(food.amount * portion * 100) / 100 };
              setQuantity(nextQuantity);
              onQuantityChanged(food.id, nextQuantity);
              setPanel("main");
            }} type="button">Save remaining amount</button>
          </div>
        )}
        {panel === "usedUp" && (
          <div className="inline-panel used-up-confirmation">
            <div className="panel-heading"><strong>Remove {food.name}?</strong></div>
            <p>This marks the ingredient as used up and removes it from your fridge.</p>
            <div>
              <button className="secondary" onClick={() => setPanel("main")} type="button">Cancel</button>
              <button className="primary" onClick={() => {
                onUsedUp(food.id);
                close();
              }} type="button">Yes, Used Up</button>
            </div>
          </div>
        )}
        {panel === "share" && (
          <div className="inline-panel">
            <div className="panel-heading">
              <strong>Who can see this?</strong>
              <button
                onClick={() => {
                  onSharingChanged(food.id, sharing !== "Just Me");
                  setPanel("main");
                }}
                type="button"
              >Done</button>
            </div>
            <div className="share-picker">
              {(["Just Me", "Everyone", "Selected Roommates"] as const)
                .filter((option) => roommates.length > 0 || option === "Just Me")
                .map((option) => (
                  <button className={sharing === option ? "selected" : ""} onClick={() => setSharing(option)} type="button" key={option}>{option}</button>
                ))}
            </div>
            {sharing === "Selected Roommates" && (
              <div className="roommate-picker">
                {roommates.map((name) => (
                  <button className={selectedRoommates.includes(name) ? "selected" : ""} onClick={() => toggleRoommate(name)} type="button" key={name}>
                    <span>{name[0]}</span>{name}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}
        {panel === "rescue" && (
          <div className="inline-panel share-with-panel">
            <div className="panel-heading"><strong>Share it with...</strong><span>Select one or more</span></div>
            <div className="checkbox-picker">
              <button className={sharing === "Everyone" ? "selected" : ""} onClick={() => {
                setSharing("Everyone");
                setSelectedRoommates([]);
              }} type="button"><i>{sharing === "Everyone" ? "✓" : ""}</i><span>Everyone</span></button>
              {roommates.map((name) => {
                const selected = sharing === "Selected Roommates" && selectedRoommates.includes(name);
                return (
                  <button className={selected ? "selected" : ""} onClick={() => {
                    setSharing("Selected Roommates");
                    setSelectedRoommates((current) => current.includes(name) ? current.filter((roommate) => roommate !== name) : [...current, name]);
                  }} type="button" key={name}><i>{selected ? "✓" : ""}</i><span>{name}</span></button>
                );
              })}
            </div>
            <button
              className="primary notify-button"
              onClick={() => {
                const recipients = sharing === "Everyone" ? roommates : selectedRoommates;
                onSharingChanged(food.id, true);
                close();
                onOffer(food, recipients);
              }}
              disabled={sharing === "Selected Roommates" && selectedRoommates.length === 0}
              type="button"
            >Share ingredient</button>
          </div>
        )}
      </section>
    </div>
  );
}

function Camera({ setScreen }: { setScreen: (screen: Screen) => void }) {
  return (
    <main className="camera-screen">
      <div className="camera-photo">
        <img alt="Five groceries ready to scan together" src={photos.produce} />
        <div className="focus-corners" />
      </div>
      <button className="camera-back" onClick={() => setScreen("home")} aria-label="Close camera" type="button">
        <Icon name="back" />
      </button>
      <div className="camera-copy">
        <Icon name="sparkle" size={19} />
        <span>Fit all your groceries in the frame</span>
      </div>
      <button className="shutter" onClick={() => setScreen("details")} aria-label="Take photo" type="button">
        <span />
      </button>
    </main>
  );
}

function FoodForm({
  setScreen,
  onComplete,
  roommates,
}: {
  setScreen: (screen: Screen) => void;
  onComplete: (items: Array<{ food: Food; sharing: string }>) => void;
  roommates: string[];
}) {
  const [activeItem, setActiveItem] = useState(0);
  const [selectedRoommates, setSelectedRoommates] = useState(roommates.slice(0, 1));
  const [detected, setDetected] = useState([
    { food: foods[1], name: "Avocado", date: "May 27", quantity: "2 pieces", sharing: "Just Me" },
    { food: foods[3], name: "Cucumber", date: "May 26", quantity: "1 piece", sharing: "Just Me" },
    { food: foods[0], name: "Oat milk", date: "May 25", quantity: "Half", sharing: "Just Me" },
    { food: foods[4], name: "Pears", date: "May 30", quantity: "3 pieces", sharing: "Just Me" },
    { food: foods[2], name: "Fresh veggies", date: "Jun 1", quantity: "1 basket", sharing: "Everyone" },
  ]);
  const item = detected[activeItem];
  const updateItem = (field: "name" | "date" | "quantity" | "sharing", value: string) => {
    setDetected((current) =>
      current.map((detectedItem, index) => index === activeItem ? { ...detectedItem, [field]: value } : detectedItem),
    );
  };

  return (
    <main className="form-screen">
      <button className="round-back" onClick={() => setScreen("camera")} aria-label="Back to camera" type="button">
        <Icon name="back" />
      </button>
      <p className="step-label">5 ITEMS FOUND</p>
      <h1>Review & Edit</h1>
      <div className="cutout-preview five-item-preview">
        <div className="detected-items">
          {detected.map((detectedItem, index) => (
            <div
              className={activeItem === index ? "active" : ""}
              onClick={() => setActiveItem(index)}
              onKeyDown={(event) => event.key === "Enter" && setActiveItem(index)}
              role="button"
              tabIndex={0}
              key={detectedItem.food.id}
            >
              <Sticker food={detectedItem.food} small />
              <span>{index + 1}</span>
            </div>
          ))}
        </div>
        <span><Icon name="sparkle" size={16} /> AI found 5 groceries</span>
      </div>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          onComplete(detected);
          setScreen("home");
        }}
      >
        <label>
          <span>Food name</span>
          <input value={item.name} onChange={(event) => updateItem("name", event.target.value)} />
        </label>
        <div className="form-row">
          <label>
            <span>Estimated expiry</span>
            <input value={item.date} onChange={(event) => updateItem("date", event.target.value)} />
          </label>
          <label>
            <span>Quantity</span>
            <input value={item.quantity} onChange={(event) => updateItem("quantity", event.target.value)} />
          </label>
        </div>
        <div className="scan-sharing">
          <span>Sharing</span>
          <div className="share-picker">
            {["Just Me", ...(roommates.length > 0 ? ["Everyone", "Selected Roommates"] : [])].map((option) => (
              <button
                className={item.sharing === option ? "selected" : ""}
                onClick={() => updateItem("sharing", option)}
                type="button"
                key={option}
              >{option}</button>
            ))}
          </div>
          {item.sharing === "Selected Roommates" && (
            <div className="roommate-picker compact">
              {roommates.map((name) => (
                <button
                  className={selectedRoommates.includes(name) ? "selected" : ""}
                  onClick={() => setSelectedRoommates((current) =>
                    current.includes(name) ? current.filter((person) => person !== name) : [...current, name],
                  )}
                  type="button"
                  key={name}
                ><span>{name[0]}</span>{name}</button>
              ))}
            </div>
          )}
        </div>
        <button className="primary form-submit" type="submit">Add 5 · AI organize <Icon name="sparkle" size={20} /></button>
      </form>
    </main>
  );
}

function CategoryScreen({
  category,
  sharedFoodIds,
  activeFoodIds,
  quantities,
  onBack,
  onFood,
}: {
  category: Category;
  sharedFoodIds: string[];
  activeFoodIds: string[];
  quantities: Record<string, Quantity>;
  onBack: () => void;
  onFood: (food: Food) => void;
}) {
  const sharedIds = new Set(sharedFoodIds);
  const availableFoods = foods.filter((food) => activeFoodIds.includes(food.id));
  const categoryFoods =
    category === "shared"
      ? availableFoods.filter((food) => food.freshness === "fresh" && sharedIds.has(food.id))
      : category === "expiring"
        ? availableFoods.filter((food) => food.freshness !== "fresh")
        : availableFoods.filter((food) => food.freshness === "fresh" && !sharedIds.has(food.id));
  const titles = { personal: "Personal", shared: "Shared", expiring: "Almost Expired" };

  return (
    <main className={`screen category-screen ${category}-category`}>
      <button className="round-back category-back" onClick={onBack} aria-label="Back to fridge" type="button"><Icon name="back" /></button>
      <div className="category-heading">
        <p className="eyebrow">YOUR FRIDGE</p>
        <h1>{titles[category]}</h1>
        <p>{categoryFoods.length} {categoryFoods.length === 1 ? "ingredient" : "ingredients"}</p>
      </div>
      <div className="ingredient-list">
        {categoryFoods.map((food) => (
          <button className="ingredient-row" onClick={() => onFood(food)} type="button" key={food.id}>
            <Sticker food={food} small />
            <div><strong>{food.name}</strong><span>Expires {food.date} · {food.days}</span></div>
            <b>{quantities[food.id].amount} {quantities[food.id].unit}</b>
          </button>
        ))}
      </div>
    </main>
  );
}

function SharedScreen({ onFood, offer, userName, onProfile }: { onFood: (food: Food) => void; offer: { food: Food; recipients: string[] } | null; userName: string; onProfile: () => void }) {
  const [claimed, setClaimed] = useState(false);
  const recipientCopy = offer?.recipients.length ? offer.recipients.join(", ") : "your roommates";
  return (
    <main className="screen shared-screen">
      <Header title="Shared Fridge" subtitle="ROOMMATE RESCUE" userName={userName} onProfile={onProfile} />
      <div className={`request-card ${claimed ? "rescued" : ""}`}>
        <span className="request-avatar">{userName[0]?.toUpperCase()}</span>
        <div>
          <strong>{claimed ? "Food Rescued!" : `${userName} · offer sent`}</strong>
          <p>{claimed ? `${offer?.food.name ?? "This item"} was claimed.` : `${offer?.food.name ?? "Oat milk"} offered to ${recipientCopy}.`}</p>
        </div>
        <button onClick={() => setClaimed(true)} type="button">{claimed ? "Claimed" : "I'll Take It"}</button>
      </div>
      <div className="legend">
        <span><i className="green-dot" /> OK to use</span>
        <span><Icon name="lock" size={13} /> Roommate's private food</span>
      </div>
      <Fridge shared onFood={onFood} />
    </main>
  );
}

type Recipe = {
  name: string;
  image: string;
  time: string;
  servings: number;
  ingredients: Array<{ name: string; foodId?: string; amount: string }>;
  steps: string[];
};

function RecipesScreen({
  userName,
  onProfile,
  activeFoodIds,
  quantities,
  onQuantitiesChanged,
  onGoHome,
}: {
  userName: string;
  onProfile: () => void;
  activeFoodIds: string[];
  quantities: Record<string, Quantity>;
  onQuantitiesChanged: (updates: Record<string, Quantity>) => void;
  onGoHome: () => void;
}) {
  const [query, setQuery] = useState("");
  const [mode, setMode] = useState<"list" | "details" | "cooking" | "update">("list");
  const [selectedRecipe, setSelectedRecipe] = useState<Recipe | null>(null);
  const [cookingStep, setCookingStep] = useState(0);
  const [portions, setPortions] = useState<Record<string, number>>({});
  const recipes: Recipe[] = [
    {
      name: "Creamy avocado toast", image: photos.toast, time: "12 min", servings: 2,
      ingredients: [{ name: "Avocado", foodId: "avocado", amount: "1 ripe" }, { name: "Oat milk", foodId: "milk", amount: "2 tbsp" }, { name: "Sourdough", amount: "2 slices" }],
      steps: ["Toast the sourdough until the edges are golden.", "Mash the avocado with oat milk, salt, and pepper.", "Spoon the avocado onto the toast and finish with your favorite seasoning."],
    },
    {
      name: "Clean-out-the-fridge pasta", image: photos.pasta, time: "25 min", servings: 3,
      ingredients: [{ name: "Cucumber", foodId: "cucumber", amount: "½" }, { name: "Fresh veggies", foodId: "veg", amount: "1 cup" }, { name: "Pasta", amount: "250 g" }],
      steps: ["Boil the pasta until just tender, then reserve a little cooking water.", "Chop the vegetables and sauté until bright and tender.", "Toss everything together with a splash of pasta water and season to taste."],
    },
    {
      name: "Crunchy green salad", image: photos.salad, time: "10 min", servings: 2,
      ingredients: [{ name: "Cucumber", foodId: "cucumber", amount: "1" }, { name: "Avocado", foodId: "avocado", amount: "1" }, { name: "Feta", amount: "½ cup" }],
      steps: ["Slice the cucumber and avocado into bite-sized pieces.", "Whisk olive oil, lemon, salt, and pepper into a quick dressing.", "Toss gently with feta and serve right away."],
    },
  ];

  const openRecipe = (recipe: Recipe) => {
    setSelectedRecipe(recipe);
    setMode("details");
  };
  const startCooking = () => {
    setCookingStep(0);
    setMode("cooking");
  };
  const finishCooking = () => {
    if (!selectedRecipe) return;
    setPortions(Object.fromEntries(
      selectedRecipe.ingredients
        .filter((ingredient) => ingredient.foodId && activeFoodIds.includes(ingredient.foodId))
        .map((ingredient) => {
          const food = foods.find((item) => item.id === ingredient.foodId)!;
          return [food.id, Math.max(0, Math.min(1, quantities[food.id].amount / food.amount))];
        }),
    ));
    setMode("update");
  };

  if (selectedRecipe && mode === "details") {
    return (
      <main className="screen recipe-detail-screen">
        <button className="round-back recipe-back" onClick={() => setMode("list")} aria-label="Back to recipes" type="button"><Icon name="back" /></button>
        <img className="recipe-hero-image" alt={selectedRecipe.name} src={selectedRecipe.image} />
        <div className="recipe-detail-body">
          <p className="eyebrow">MADE FOR YOUR FRIDGE</p>
          <h1>{selectedRecipe.name}</h1>
          <div className="recipe-meta"><span><Icon name="clock" size={16} /> {selectedRecipe.time}</span><span>{selectedRecipe.servings} servings</span></div>
          <h2>What you’ll need</h2>
          <div className="required-ingredients">
            {selectedRecipe.ingredients.map((ingredient) => {
              const available = Boolean(ingredient.foodId && activeFoodIds.includes(ingredient.foodId));
              return <div className={available ? "available" : "missing"} key={ingredient.name}><span>{available ? "✓" : "−"}</span><strong>{ingredient.name}</strong><small>{ingredient.amount} · {available ? "In your fridge" : "Missing"}</small></div>;
            })}
          </div>
          <h2>Instructions</h2>
          <ol className="recipe-steps">{selectedRecipe.steps.map((step) => <li key={step}>{step}</li>)}</ol>
          <button className="primary start-cooking" onClick={startCooking} type="button">Start Cooking</button>
        </div>
      </main>
    );
  }

  if (selectedRecipe && mode === "cooking") {
    const isLastStep = cookingStep === selectedRecipe.steps.length - 1;
    return (
      <main className="screen cooking-screen">
        <button className="round-back recipe-back" onClick={() => setMode("details")} aria-label="Leave cooking mode" type="button"><Icon name="back" /></button>
        <p className="step-label">STEP {cookingStep + 1} OF {selectedRecipe.steps.length}</p>
        <div className="cooking-progress"><i style={{ width: `${((cookingStep + 1) / selectedRecipe.steps.length) * 100}%` }} /></div>
        <Sticker food={foods.find((food) => selectedRecipe.ingredients.some((ingredient) => ingredient.foodId === food.id)) ?? foods[0]} />
        <h1>{selectedRecipe.steps[cookingStep]}</h1>
        <p>Take your time. Your fridge will only update after you confirm what’s left.</p>
        <div className="cooking-actions">
          <button className="secondary" disabled={cookingStep === 0} onClick={() => setCookingStep((step) => step - 1)} type="button">Back</button>
          <button className="primary" onClick={() => isLastStep ? finishCooking() : setCookingStep((step) => step + 1)} type="button">{isLastStep ? "Finish Cooking" : "Next Step"}</button>
        </div>
      </main>
    );
  }

  if (selectedRecipe && mode === "update") {
    const fridgeIngredients = selectedRecipe.ingredients.filter((ingredient) => ingredient.foodId && activeFoodIds.includes(ingredient.foodId));
    return (
      <main className="screen ingredient-update-screen">
        <p className="step-label">ONE LAST THING</p>
        <h1>Update Ingredients Used</h1>
        <p>Set how much is left. Nothing changes until you save.</p>
        <div className="cooked-ingredient-list">
          {fridgeIngredients.map((ingredient) => {
            const food = foods.find((item) => item.id === ingredient.foodId)!;
            return <section key={food.id}><div><Sticker food={food} small /><span><strong>{food.name}</strong><small>{quantities[food.id].amount} {quantities[food.id].unit} before cooking</small></span></div><PortionSelector compact value={portions[food.id] ?? 0} onChange={(value) => setPortions((current) => ({ ...current, [food.id]: value }))} /></section>;
          })}
        </div>
        <button className="primary save-cooking" onClick={() => {
          const updates = Object.fromEntries(fridgeIngredients.map((ingredient) => {
            const food = foods.find((item) => item.id === ingredient.foodId)!;
            return [food.id, { ...quantities[food.id], amount: Math.round(food.amount * (portions[food.id] ?? 0) * 100) / 100 }];
          }));
          onQuantitiesChanged(updates);
          setMode("details");
        }} type="button">Save ingredient updates</button>
        <button className="text-button" onClick={onGoHome} type="button">Save later · Return to fridge</button>
      </main>
    );
  }

  return (
    <main className="screen recipes-screen">
      <Header title="Cook it soon" subtitle="RECIPES FOR YOUR FRIDGE" userName={userName} onProfile={onProfile} />
      <section className="expiring-strip">
        <div className="section-title"><h2>Use these first</h2><span>Prioritized</span></div>
        <div className="food-row">
          {foods.filter((food) => activeFoodIds.includes(food.id) && food.freshness !== "fresh").map((food) => <Sticker food={food} small key={food.id} />)}
          {!activeFoodIds.some((id) => foods.find((food) => food.id === id)?.freshness !== "fresh") && <span className="all-fresh">Nothing expiring yet</span>}
        </div>
      </section>
      <section className="recipe-list">
        <div className="section-title"><h2>Made for your fridge</h2><span>See all</span></div>
        <label className="recipe-search">
          <Icon name="sparkle" size={17} />
          <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search recipes or ingredients" />
        </label>
        {recipes.filter((recipe) => `${recipe.name} ${recipe.ingredients.map((ingredient) => ingredient.name).join(" ")}`.toLowerCase().includes(query.toLowerCase())).map((recipe) => (
          <article className="recipe-card" onClick={() => openRecipe(recipe)} key={recipe.name}>
            <img alt={recipe.name} src={recipe.image} />
            <div className="recipe-info">
              <div className="cook-time"><Icon name="clock" size={15} /> {recipe.time}</div>
              <h3>{recipe.name}</h3>
              <div className="ingredients">
                {recipe.ingredients.map((ingredient) => <span className={ingredient.foodId && activeFoodIds.includes(ingredient.foodId) ? "have" : ""} key={ingredient.name}>{ingredient.name}</span>)}
              </div>
            </div>
          </article>
        ))}
      </section>
    </main>
  );
}

function Onboarding({
  initialProfile,
  onSave,
  onCancel,
}: {
  initialProfile?: UserProfile;
  onSave: (profile: UserProfile) => void;
  onCancel?: () => void;
}) {
  const [step, setStep] = useState(0);
  const [name, setName] = useState(initialProfile?.name ?? "");
  const [roommates, setRoommates] = useState(initialProfile?.roommates.length ? initialProfile.roommates : [""]);
  const editing = Boolean(initialProfile);

  const changeRoommateCount = (change: number) => {
    setRoommates((current) => {
      const count = Math.min(6, Math.max(1, current.length + change));
      return Array.from({ length: count }, (_, index) => current[index] ?? "");
    });
  };

  return (
    <main className="onboarding-screen">
      <div className="onboarding-doodle"><Icon name="fridge" size={58} strokeWidth={1.7} /><span>fresh start</span></div>
      <p className="step-label">{editing ? "EDIT YOUR FRIDGE CREW" : `WELCOME · ${step + 1} OF ${step === 2 ? 3 : 2}`}</p>
      {step === 0 && (
        <section className="onboarding-card">
          <h1>{editing ? "What should we call you?" : "Let’s stock your fridge"}</h1>
          <p>Your name helps everyone know what belongs to whom.</p>
          <label><span>Your name</span><input autoFocus placeholder="e.g. Jamie" value={name} onChange={(event) => setName(event.target.value)} /></label>
          <button className="primary onboarding-next" disabled={!name.trim()} onClick={() => setStep(1)} type="button">Continue</button>
        </section>
      )}
      {step === 1 && (
        <section className="onboarding-card">
          <h1>Who shares this fridge?</h1>
          <p>We’ll use this to make sharing food feel effortless.</p>
          <div className="household-options">
            <button onClick={() => onSave({ name: name.trim(), household: "alone", roommates: [] })} type="button">
              <span><Icon name="lock" /></span><strong>I live alone</strong><small>Keep everything personal</small>
            </button>
            <button onClick={() => setStep(2)} type="button">
              <span><Icon name="users" /></span><strong>With roommates</strong><small>Choose who can share</small>
            </button>
          </div>
          <button className="text-button" onClick={() => setStep(0)} type="button">Back</button>
        </section>
      )}
      {step === 2 && (
        <section className="onboarding-card roommate-setup">
          <h1>Meet the fridge crew</h1>
          <p>Add each roommate so you can choose exactly who to share with.</p>
          <div className="roommate-count"><span>Roommates</span><button onClick={() => changeRoommateCount(-1)} type="button">−</button><strong>{roommates.length}</strong><button onClick={() => changeRoommateCount(1)} type="button">+</button></div>
          <div className="roommate-inputs">
            {roommates.map((roommate, index) => (
              <label key={index}><span>{index + 1}</span><input aria-label={`Roommate ${index + 1} name`} placeholder="Roommate name" value={roommate} onChange={(event) => setRoommates((current) => current.map((value, roommateIndex) => roommateIndex === index ? event.target.value : value))} /></label>
            ))}
          </div>
          <button className="primary onboarding-next" disabled={roommates.some((roommate) => !roommate.trim())} onClick={() => onSave({ name: name.trim(), household: "roommates", roommates: roommates.map((roommate) => roommate.trim()) })} type="button">{editing ? "Save changes" : "Open my fridge"}</button>
          <button className="text-button" onClick={() => setStep(1)} type="button">Back</button>
        </section>
      )}
      {editing && onCancel && <button className="onboarding-close" aria-label="Close profile editor" onClick={onCancel} type="button">×</button>}
    </main>
  );
}

function loadProfile(): UserProfile | null {
  try {
    const saved = localStorage.getItem("fridge-profile");
    if (!saved) return null;

    const candidate: unknown = JSON.parse(saved);
    if (
      typeof candidate !== "object"
      || candidate === null
      || !("name" in candidate)
      || typeof candidate.name !== "string"
      || !candidate.name.trim()
    ) {
      localStorage.removeItem("fridge-profile");
      return null;
    }

    const roommates = "roommates" in candidate && Array.isArray(candidate.roommates)
      ? candidate.roommates.filter((name): name is string => typeof name === "string" && Boolean(name.trim())).map((name) => name.trim())
      : [];

    return {
      name: candidate.name.trim(),
      household: roommates.length > 0 ? "roommates" : "alone",
      roommates,
    };
  } catch {
    localStorage.removeItem("fridge-profile");
    return null;
  }
}

type SharingNotification = { foodId: string; roommate: string; verb: "shared" | "offered" };
type StoredInventory = {
  activeFoodIds: string[];
  sharedFoodIds: string[];
  quantities: Record<string, Quantity>;
  owners: Record<string, string>;
  receivedFoodIds: string[];
  highlightedFoodIds: string[];
  sharedWith: Record<string, string[]>;
  notification: SharingNotification | null;
};

function loadInventory(): StoredInventory {
  const defaultQuantities = Object.fromEntries(foods.map((food) => [food.id, { amount: food.amount, unit: food.unit }]));
  const emptyInventory: StoredInventory = {
    activeFoodIds: [],
    sharedFoodIds: [],
    quantities: defaultQuantities,
    owners: {},
    receivedFoodIds: [],
    highlightedFoodIds: [],
    sharedWith: {},
    notification: null,
  };
  try {
    const saved = localStorage.getItem("fridge-inventory");
    if (!saved) return emptyInventory;
    const candidate = JSON.parse(saved) as Partial<StoredInventory>;
    return {
      activeFoodIds: Array.isArray(candidate.activeFoodIds) ? candidate.activeFoodIds.filter((id) => foods.some((food) => food.id === id)) : [],
      sharedFoodIds: Array.isArray(candidate.sharedFoodIds) ? candidate.sharedFoodIds.filter((id) => foods.some((food) => food.id === id)) : [],
      quantities: { ...defaultQuantities, ...(candidate.quantities ?? {}) },
      owners: candidate.owners ?? {},
      receivedFoodIds: Array.isArray(candidate.receivedFoodIds) ? candidate.receivedFoodIds : [],
      highlightedFoodIds: Array.isArray(candidate.highlightedFoodIds) ? candidate.highlightedFoodIds : [],
      sharedWith: candidate.sharedWith ?? {},
      notification: candidate.notification ?? null,
    };
  } catch {
    localStorage.removeItem("fridge-inventory");
    return emptyInventory;
  }
}

export default function App() {
  const [inventorySeed] = useState(loadInventory);
  const [profile, setProfile] = useState<UserProfile | null>(loadProfile);
  const [editingProfile, setEditingProfile] = useState(false);
  const [screen, setScreen] = useState<Screen>("home");
  const [detailFood, setDetailFood] = useState<Food | null>(null);
  const [sharedFoodIds, setSharedFoodIds] = useState<string[]>(inventorySeed.sharedFoodIds);
  const [activeFoodIds, setActiveFoodIds] = useState<string[]>(inventorySeed.activeFoodIds);
  const [quantities, setQuantities] = useState<Record<string, Quantity>>(inventorySeed.quantities);
  const [owners, setOwners] = useState<Record<string, string>>(inventorySeed.owners);
  const [receivedFoodIds, setReceivedFoodIds] = useState<string[]>(inventorySeed.receivedFoodIds);
  const [highlightedFoodIds, setHighlightedFoodIds] = useState<string[]>(inventorySeed.highlightedFoodIds);
  const [sharedWith, setSharedWith] = useState<Record<string, string[]>>(inventorySeed.sharedWith);
  const [sharingNotification, setSharingNotification] = useState<SharingNotification | null>(inventorySeed.notification);
  const [offer, setOffer] = useState<{ food: Food; recipients: string[] } | null>(null);
  const [category, setCategory] = useState<Category>("personal");

  useEffect(() => {
    localStorage.setItem("fridge-inventory", JSON.stringify({
      activeFoodIds,
      sharedFoodIds,
      quantities,
      owners,
      receivedFoodIds,
      highlightedFoodIds,
      sharedWith,
      notification: sharingNotification,
    } satisfies StoredInventory));
  }, [activeFoodIds, sharedFoodIds, quantities, owners, receivedFoodIds, highlightedFoodIds, sharedWith, sharingNotification]);

  const saveProfile = (nextProfile: UserProfile) => {
    localStorage.setItem("fridge-profile", JSON.stringify(nextProfile));
    if (!profile) {
      setActiveFoodIds([]);
      setSharedFoodIds([]);
      setOwners({});
      setReceivedFoodIds([]);
      setHighlightedFoodIds([]);
      setSharedWith({});
      setSharingNotification(null);
    }
    setProfile(nextProfile);
    setEditingProfile(false);
  };

  if (!profile) return <Onboarding onSave={saveProfile} />;
  if (editingProfile) return <Onboarding initialProfile={profile} onSave={saveProfile} onCancel={() => setEditingProfile(false)} />;

  if (screen === "camera") return <Camera setScreen={setScreen} />;
  if (screen === "details") {
    return (
      <FoodForm
        setScreen={setScreen}
        onComplete={(items) => {
          const itemIds = items.map(({ food }) => food.id);
          const nextSharedIds = items.filter(({ sharing }) => sharing !== "Just Me").map(({ food }) => food.id);
          setActiveFoodIds((current) => [...new Set([...current, ...itemIds])]);
          setSharedFoodIds((current) => [...new Set([...current.filter((id) => !itemIds.includes(id)), ...nextSharedIds])]);
          setOwners((current) => ({ ...current, ...Object.fromEntries(itemIds.map((id) => [id, profile.name])) }));
          setQuantities((current) => ({
            ...current,
            ...Object.fromEntries(items.map(({ food }) => [food.id, { amount: food.amount, unit: food.unit }])),
          }));
        }}
        roommates={profile.roommates}
      />
    );
  }

  return (
    <div className="app-shell">
      {screen === "home" && (
        <main className="screen home-screen">
          <Header title="My Fridge" subtitle={`GOOD MORNING, ${profile.name.toUpperCase()}`} userName={profile.name} onProfile={() => setEditingProfile(true)} />
          {sharingNotification && (
            <button className="sharing-notification" onClick={() => {
              const food = foods.find((item) => item.id === sharingNotification.foodId);
              if (food) {
                setHighlightedFoodIds((current) => current.filter((id) => id !== food.id));
                setSharingNotification(null);
                setDetailFood(food);
              }
            }} type="button">
              <span><Icon name="sparkle" size={17} /></span>
              <p><strong>{sharingNotification.roommate} {sharingNotification.verb} {foods.find((food) => food.id === sharingNotification.foodId)?.name.toLowerCase()} with you!</strong><small>Tap to view ingredient</small></p>
            </button>
          )}
          {activeFoodIds.length === 0 && <div className="empty-fridge-message"><Icon name="camera" size={20} /><span><strong>Your fridge is empty!</strong> Scan your first groceries to get started.</span></div>}
          <Fridge
            sharedFoodIds={sharedFoodIds}
            activeFoodIds={activeFoodIds}
            highlightedFoodIds={highlightedFoodIds}
            owners={owners}
            currentUser={profile.name}
            onFood={(food) => {
              setHighlightedFoodIds((current) => current.filter((id) => id !== food.id));
              if (sharingNotification?.foodId === food.id) setSharingNotification(null);
              setDetailFood(food);
            }}
            onOpenCategory={(nextCategory) => {
              setCategory(nextCategory);
              setScreen("category");
            }}
          />
        </main>
      )}
      {screen === "category" && (
        <CategoryScreen
          category={category}
          sharedFoodIds={sharedFoodIds}
          activeFoodIds={activeFoodIds}
          quantities={quantities}
          onBack={() => setScreen("home")}
          onFood={setDetailFood}
        />
      )}
      {screen === "shared" && <SharedScreen onFood={setDetailFood} offer={offer} userName={profile.name} onProfile={() => setEditingProfile(true)} />}
      {screen === "recipes" && <RecipesScreen
        userName={profile.name}
        onProfile={() => setEditingProfile(true)}
        activeFoodIds={activeFoodIds}
        quantities={quantities}
        onQuantitiesChanged={(updates) => setQuantities((current) => ({ ...current, ...updates }))}
        onGoHome={() => setScreen("home")}
      />}
      <BottomNav screen={screen} setScreen={setScreen} />
      {detailFood && (
        <DetailSheet
          food={detailFood}
          close={() => setDetailFood(null)}
          openRecipes={() => {
            setDetailFood(null);
            setScreen("recipes");
          }}
          isShared={sharedFoodIds.includes(detailFood.id)}
          roommates={profile.roommates}
          owner={owners[detailFood.id] ?? profile.name}
          sharedByRoommate={receivedFoodIds.includes(detailFood.id)}
          sharedWith={sharedWith[detailFood.id] ?? []}
          savedQuantity={quantities[detailFood.id]}
          onQuantityChanged={(foodId, quantity) => setQuantities((current) => ({ ...current, [foodId]: quantity }))}
          onUsedUp={(foodId) => {
            setActiveFoodIds((current) => current.filter((id) => id !== foodId));
            setHighlightedFoodIds((current) => current.filter((id) => id !== foodId));
            if (sharingNotification?.foodId === foodId) setSharingNotification(null);
          }}
          onOffer={(food, recipients) => {
            setOffer({ food, recipients });
            setSharedWith((current) => ({ ...current, [food.id]: recipients }));
            setScreen("home");
          }}
          onSharingChanged={(foodId, shared) => {
            setSharedFoodIds((current) =>
              shared
                ? (current.includes(foodId) ? current : [...current, foodId])
                : current.filter((id) => id !== foodId),
            );
          }}
        />
      )}
    </div>
  );
}
