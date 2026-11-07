import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using System.Collections.Generic;

public class ZaynCompleteGame : MonoBehaviour
{
    public static ZaynCompleteGame Instance;

    [Header("PLAYER")]
    public CharacterController controller;
    public Transform playerCamera;
    public Transform attackPoint;
    public Transform firePoint;

    [Header("MOVEMENT")]
    public float moveSpeed = 6f;
    public float gravity = -20f;
    public float jumpHeight = 2f;
    public float rotationSpeed = 12f;
    public float dashSpeed = 18f;
    public float dashDuration = 0.25f;

    [Header("HEALTH")]
    public int maxHealth = 100;
    public int currentHealth;

    [Header("ENERGY")]
    public int maxEnergy = 100;
    public int currentEnergy;
    public int energyCost = 20;

    [Header("COMBAT")]
    public int meleeDamage = 25;
    public int energyDamage = 35;
    public float attackRange = 2f;
    public float attackCooldown = 0.5f;
    public float energyCooldown = 1f;
    public LayerMask enemyLayer;
    public GameObject energyPrefab;

    [Header("SHIELD")]
    public bool shieldActive;
    public float shieldDuration = 3f;
    public float shieldCooldown = 8f;

    [Header("ULTIMATE")]
    public int ultimateDamage = 100;
    public float ultimateCooldown = 15f;

    [Header("MISSION")]
    public int enemiesRequired = 5;
    public int enemiesDefeated;
    public bool missionCompleted;

    [Header("CURRENCY")]
    public int coins;
    public int experience;
    public int level = 1;

    [Header("UI")]
    public Slider healthBar;
    public Slider energyBar;
    public Text healthText;
    public Text energyText;
    public Text coinsText;
    public Text missionText;

    [Header("ENEMIES")]
    public GameObject enemyPrefab;
    public GameObject fastEnemyPrefab;
    public GameObject strongEnemyPrefab;
    public Transform[] enemySpawnPoints;

    [Header("BOSS")]
    public GameObject bossPrefab;
    public Transform bossSpawnPoint;
    public bool bossSpawned;

    private Vector2 moveInput;
    private Vector3 velocity;

    private bool attackPressed;
    private bool energyPressed;
    private bool jumpPressed;
    private bool dashPressed;
    private bool shieldPressed;
    private bool ultimatePressed;

    private float nextAttackTime;
    private float nextEnergyTime;
    private float nextShieldTime;
    private float nextUltimateTime;

    private bool isDashing;
    private float dashTimer;
    private bool isDead;

    void Awake()
    {
        Instance = this;
    }

    void Start()
    {
        if (controller == null)
            controller = GetComponent<CharacterController>();

        currentHealth = maxHealth;
        currentEnergy = maxEnergy;

        SpawnMissionEnemies();
        UpdateUI();
    }

    void Update()
    {
        if (isDead)
            return;

        HandleMovement();
        HandleButtons();
        RegenerateEnergy();
        UpdateUI();
    }

    void HandleMovement()
    {
        Vector3 direction = new Vector3(
            moveInput.x,
            0f,
            moveInput.y
        );

#if UNITY_EDITOR
        direction += new Vector3(
            Input.GetAxis("Horizontal"),
            0f,
            Input.GetAxis("Vertical")
        );

        if (Input.GetButtonDown("Jump"))
            jumpPressed = true;

        if (Input.GetKeyDown(KeyCode.LeftShift))
            dashPressed = true;

        if (Input.GetKeyDown(KeyCode.Q))
            shieldPressed = true;

        if (Input.GetKeyDown(KeyCode.E))
            ultimatePressed = true;

        if (Input.GetMouseButtonDown(0))
            attackPressed = true;

        if (Input.GetMouseButtonDown(1))
            energyPressed = true;
#endif

        if (isDashing)
        {
            controller.Move(
                transform.forward *
                dashSpeed *
                Time.deltaTime
            );

            dashTimer -= Time.deltaTime;

            if (dashTimer <= 0f)
                isDashing = false;
        }
        else if (direction.magnitude > 0.1f)
        {
            if (playerCamera != null)
            {
                direction =
                    playerCamera.TransformDirection(direction);

                direction.y = 0f;
            }

            direction.Normalize();

            controller.Move(
                direction *
                moveSpeed *
                Time.deltaTime
            );

            Quaternion targetRotation =
                Quaternion.LookRotation(direction);

            transform.rotation =
                Quaternion.Slerp(
                    transform.rotation,
                    targetRotation,
                    rotationSpeed * Time.deltaTime
                );
        }

        if (
            controller.isGrounded &&
            velocity.y < 0f
        )
        {
            velocity.y = -2f;
        }

        if (
            jumpPressed &&
            controller.isGrounded
        )
        {
            velocity.y =
                Mathf.Sqrt(
                    jumpHeight *
                    -2f *
                    gravity
                );

            jumpPressed = false;
        }

        velocity.y += gravity * Time.deltaTime;

        controller.Move(
            velocity * Time.deltaTime
        );
    }

    void HandleButtons()
    {
        if (attackPressed)
        {
            MeleeAttack();
            attackPressed = false;
        }

        if (energyPressed)
        {
            EnergyAttack();
            energyPressed = false;
        }

        if (dashPressed)
        {
            Dash();
            dashPressed = false;
        }

        if (shieldPressed)
        {
            ActivateShield();
            shieldPressed = false;
        }

        if (ultimatePressed)
        {
            UltimateAttack();
            ultimatePressed = false;
        }
    }

    public void SetMove(Vector2 value)
    {
        moveInput = value;
    }

    public void AttackButton()
    {
        attackPressed = true;
    }

    public void EnergyButton()
    {
        energyPressed = true;
    }

    public void JumpButton()
    {
        jumpPressed = true;
    }

    public void DashButton()
    {
        dashPressed = true;
    }

    public void ShieldButton()
    {
        shieldPressed = true;
    }

    public void UltimateButton()
    {
        ultimatePressed = true;
    }

    void MeleeAttack()
    {
        if (Time.time < nextAttackTime)
            return;

        nextAttackTime =
            Time.time + attackCooldown;

        if (attackPoint == null)
            return;

        Collider[] hits =
            Physics.OverlapSphere(
                attackPoint.position,
                attackRange,
                enemyLayer
            );

        foreach (Collider hit in hits)
        {
            ZaynEnemy enemy =
                hit.GetComponentInParent<ZaynEnemy>();

            if (enemy != null)
                enemy.TakeDamage(meleeDamage);
        }
    }

    void EnergyAttack()
    {
        if (Time.time < nextEnergyTime)
            return;

        if (currentEnergy < energyCost)
            return;

        currentEnergy -= energyCost;

        nextEnergyTime =
            Time.time + energyCooldown;

        if (
            energyPrefab != null &&
            firePoint != null
        )
        {
            GameObject projectile =
                Instantiate(
                    energyPrefab,
                    firePoint.position,
                    firePoint.rotation
                );

            ZaynProjectile projectileScript =
                projectile.GetComponent<ZaynProjectile>();

            if (projectileScript == null)
                projectileScript =
                    projectile.AddComponent<ZaynProjectile>();

            projectileScript.damage =
                energyDamage;
        }
    }

    void Dash()
    {
        if (isDashing)
            return;

        isDashing = true;
        dashTimer = dashDuration;
    }

    void ActivateShield()
    {
        if (Time.time < nextShieldTime)
            return;

        shieldActive = true;

        nextShieldTime =
            Time.time + shieldCooldown;

        Invoke(
            nameof(DisableShield),
            shieldDuration
        );
    }

    void DisableShield()
    {
        shieldActive = false;
    }

    void UltimateAttack()
    {
        if (Time.time < nextUltimateTime)
            return;

        if (currentEnergy < 50)
            return;

        currentEnergy -= 50;

        nextUltimateTime =
            Time.time + ultimateCooldown;

        Collider[] enemies =
            Physics.OverlapSphere(
                transform.position,
                8f,
                enemyLayer
            );

        foreach (Collider hit in enemies)
        {
            ZaynEnemy enemy =
                hit.GetComponentInParent<ZaynEnemy>();

            if (enemy != null)
                enemy.TakeDamage(ultimateDamage);
        }
    }

    public void TakeDamage(int damage)
    {
        if (isDead)
            return;

        if (shieldActive)
            damage = Mathf.Max(1, damage / 4);

        currentHealth -= damage;

        currentHealth =
            Mathf.Clamp(
                currentHealth,
                0,
                maxHealth
            );

        if (currentHealth <= 0)
            Die();
    }

    public void Heal(int amount)
    {
        currentHealth =
            Mathf.Min(
                currentHealth + amount,
                maxHealth
            );
    }

    void Die()
    {
        isDead = true;

        Invoke(
            nameof(RestartPlayer),
            3f
        );
    }

    void RestartPlayer()
    {
        isDead = false;
        currentHealth = maxHealth;
        currentEnergy = maxEnergy;
    }

    void RegenerateEnergy()
    {
        if (currentEnergy < maxEnergy)
        {
            currentEnergy +=
                Mathf.CeilToInt(
                    10f * Time.deltaTime
                );

            currentEnergy =
                Mathf.Clamp(
                    currentEnergy,
                    0,
                    maxEnergy
                );
        }
    }

    public void EnemyDefeated(
        int rewardCoins,
        int rewardXP
    )
    {
        enemiesDefeated++;

        coins += rewardCoins;
        experience += rewardXP;

        CheckLevel();

        if (
            !missionCompleted &&
            enemiesDefeated >= enemiesRequired
        )
        {
            CompleteMission();
        }
    }

    void CompleteMission()
    {
        missionCompleted = true;

        if (!bossSpawned)
        {
            bossSpawned = true;

            if (
                bossPrefab != null &&
                bossSpawnPoint != null
            )
            {
                Instantiate(
                    bossPrefab,
                    bossSpawnPoint.position,
                    bossSpawnPoint.rotation
                );
            }
        }
    }

    void CheckLevel()
    {
        int requiredXP = level * 100;

        if (experience >= requiredXP)
        {
            experience -= requiredXP;
            level++;

            maxHealth += 20;
            maxEnergy += 10;

            currentHealth = maxHealth;
            currentEnergy = maxEnergy;
        }
    }

    void SpawnMissionEnemies()
    {
        if (
            enemyPrefab == null ||
            enemySpawnPoints == null
        )
            return;

        for (
            int i = 0;
            i < enemiesRequired;
            i++
        )
        {
            Transform point =
                enemySpawnPoints[
                    i % enemySpawnPoints.Length
                ];

            Instantiate(
                enemyPrefab,
                point.position,
                point.rotation
            );
        }
    }

    void UpdateUI()
    {
        if (healthBar != null)
        {
            healthBar.maxValue = maxHealth;
            healthBar.value = currentHealth;
        }

        if (energyBar != null)
        {
            energyBar.maxValue = maxEnergy;
            energyBar.value = currentEnergy;
        }

        if (healthText != null)
        {
            healthText.text =
                "HP " +
                currentHealth +
                "/" +
                maxHealth;
        }

        if (energyText != null)
        {
            energyText.text =
                "⚡ " +
                currentEnergy +
                "/" +
                maxEnergy;
        }

        if (coinsText != null)
        {
            coinsText.text =
                "🪙 " + coins;
        }

        if (missionText != null)
        {
            if (!missionCompleted)
            {
                missionText.text =
                    "اهزم جنود الظلام " +
                    enemiesDefeated +
                    "/" +
                    enemiesRequired;
            }
            else
            {
                missionText.text =
                    "اهزم حارس الشق";
            }
        }
    }

    void OnDrawGizmosSelected()
    {
        if (attackPoint != null)
        {
            Gizmos.DrawWireSphere(
                attackPoint.position,
                attackRange
            );
        }
    }
}

public class ZaynEnemy : MonoBehaviour
{
    public int maxHealth = 100;
    public int currentHealth;

    public int damage = 10;
    public int rewardCoins = 10;
    public int rewardXP = 20;

    public float speed = 3f;
    public float detectionRange = 15f;
    public float attackRange = 2f;
    public float attackCooldown = 1.5f;

    public bool isBoss;

    private Transform player;
    private float nextAttack;
    private bool dead;

    void Start()
    {
        currentHealth = maxHealth;

        if (ZaynCompleteGame.Instance != null)
            player =
                ZaynCompleteGame.Instance.transform;
    }

    void Update()
    {
        if (dead || player == null)
            return;

        float distance =
            Vector3.Distance(
                transform.position,
                player.position
            );

        if (distance > detectionRange)
            return;

        if (distance > attackRange)
        {
            Vector3 target =
                new Vector3(
                    player.position.x,
                    transform.position.y,
                    player.position.z
                );

            transform.LookAt(target);

            transform.position =
                Vector3.MoveTowards(
                    transform.position,
                    target,
                    speed * Time.deltaTime
                );
        }
        else
        {
            Attack();
        }
    }

    void Attack()
    {
        if (Time.time < nextAttack)
            return;

        if (ZaynCompleteGame.Instance != null)
        {
            ZaynCompleteGame.Instance
                .TakeDamage(damage);
        }

        nextAttack =
            Time.time + attackCooldown;
    }

    public void TakeDamage(int amount)
    {
        if (dead)
            return;

        currentHealth -= amount;

        if (currentHealth <= 0)
            Die();
    }

    void Die()
    {
        dead = true;

        if (ZaynCompleteGame.Instance != null)
        {
            ZaynCompleteGame.Instance.EnemyDefeated(
                rewardCoins,
                rewardXP
            );
        }

        Destroy(gameObject);
    }
}

public class ZaynBoss : MonoBehaviour
{
    public int maxHealth = 500;
    public int currentHealth;

    public int damage = 25;
    public float speed = 4f;
    public float attackRange = 3f;

    public GameObject minionPrefab;
    public Transform[] spawnPoints;

    private Transform player;
    private float nextAttack;
    private bool phaseTwo;
    private bool dead;

    void Start()
    {
        currentHealth = maxHealth;

        if (ZaynCompleteGame.Instance != null)
            player =
                ZaynCompleteGame.Instance.transform;
    }

    void Update()
    {
        if (dead || player == null)
            return;

        float distance =
            Vector3.Distance(
                transform.position,
                player.position
            );

        if (
            !phaseTwo &&
            currentHealth <= maxHealth / 2
        )
        {
            phaseTwo = true;
            speed = 6f;
            damage = 40;
            SpawnMinions();
        }

        if (distance > attackRange)
        {
            transform.LookAt(
                new Vector3(
                    player.position.x,
                    transform.position.y,
                    player.position.z
                )
            );

            transform.position =
                Vector3.MoveTowards(
                    transform.position,
                    player.position,
                    speed * Time.deltaTime
                );
        }
        else
        {
            BossAttack();
        }
    }

    void BossAttack()
    {
        if (Time.time < nextAttack)
            return;

        if (ZaynCompleteGame.Instance != null)
        {
            ZaynCompleteGame.Instance
                .TakeDamage(damage);
        }

        nextAttack =
            Time.time + 1.2f;
    }

    void SpawnMinions()
    {
        if (
            minionPrefab == null ||
            spawnPoints == null
        )
            return;

        foreach (Transform point in spawnPoints)
        {
            Instantiate(
                minionPrefab,
                point.position,
                point.rotation
            );
        }
    }

    public void TakeDamage(int amount)
    {
        if (dead)
            return;

        currentHealth -= amount;

        if (currentHealth <= 0)
        {
            dead = true;

            if (ZaynCompleteGame.Instance != null)
            {
                ZaynCompleteGame.Instance.coins += 100;
                ZaynCompleteGame.Instance.experience += 200;
            }

            Destroy(gameObject);
        }
    }
}

public class ZaynProjectile : MonoBehaviour
{
    public float speed = 20f;
    public int damage = 35;
    public float lifeTime = 4f;

    void Start()
    {
        Destroy(gameObject, lifeTime);
    }

    void Update()
    {
        transform.position +=
            transform.forward *
            speed *
            Time.deltaTime;
    }

    void OnTriggerEnter(Collider other)
    {
        ZaynEnemy enemy =
            other.GetComponentInParent<ZaynEnemy>();

        if (enemy != null)
        {
            enemy.TakeDamage(damage);
            Destroy(gameObject);
            return;
        }

        ZaynBoss boss =
            other.GetComponentInParent<ZaynBoss>();

        if (boss != null)
        {
            boss.TakeDamage(damage);
            Destroy(gameObject);
        }
    }
}

public class ZaynMobileJoystick :
    MonoBehaviour,
    IPointerDownHandler,
    IDragHandler,
    IPointerUpHandler
{
    public RectTransform background;
    public RectTransform handle;
    public float radius = 100f;

    public void OnPointerDown(
        PointerEventData eventData
    )
    {
        OnDrag(eventData);
    }

    public void OnDrag(
        PointerEventData eventData
    )
    {
        if (
            background == null ||
            handle == null ||
            ZaynCompleteGame.Instance == null
        )
            return;

        Vector2 position;

        RectTransformUtility
            .ScreenPointToLocalPointInRectangle(
                background,
                eventData.position,
                eventData.pressEventCamera,
                out position
            );

        Vector2 input =
            new Vector2(
                position.x /
                (background.sizeDelta.x / 2f),

                position.y /
                (background.sizeDelta.y / 2f)
            );

        input =
            input.magnitude > 1f
            ? input.normalized
            : input;

        handle.anchoredPosition =
            input * radius;

        ZaynCompleteGame.Instance
            .SetMove(input);
    }

    public void OnPointerUp(
        PointerEventData eventData
    )
    {
        if (handle != null)
            handle.anchoredPosition =
                Vector2.zero;

        if (ZaynCompleteGame.Instance != null)
        {
            ZaynCompleteGame.Instance
                .SetMove(Vector2.zero);
        }
    }
}

public class ZaynCheckpoint : MonoBehaviour
{
    public Transform respawnPoint;

    void OnTriggerEnter(Collider other)
    {
        if (!other.CompareTag("Player"))
            return;

        PlayerPrefs.SetFloat(
            "ZaynX",
            respawnPoint.position.x
        );

        PlayerPrefs.SetFloat(
            "ZaynY",
            respawnPoint.position.y
        );

        PlayerPrefs.SetFloat(
            "ZaynZ",
            respawnPoint.position.z
        );

        PlayerPrefs.Save();
    }
}

public class ZaynSaveSystem : MonoBehaviour
{
    public void SaveGame()
    {
        if (ZaynCompleteGame.Instance == null)
            return;

        PlayerPrefs.SetInt(
            "Coins",
            ZaynCompleteGame.Instance.coins
        );

        PlayerPrefs.SetInt(
            "Experience",
            ZaynCompleteGame.Instance.experience
        );

        PlayerPrefs.SetInt(
            "Level",
            ZaynCompleteGame.Instance.level
        );

        PlayerPrefs.SetInt(
            "Health",
            ZaynCompleteGame.Instance.currentHealth
        );

        PlayerPrefs.Save();
    }

    public void LoadGame()
    {
        if (ZaynCompleteGame.Instance == null)
            return;

        ZaynCompleteGame.Instance.coins =
            PlayerPrefs.GetInt("Coins", 0);

        ZaynCompleteGame.Instance.experience =
            PlayerPrefs.GetInt("Experience", 0);

        ZaynCompleteGame.Instance.level =
            PlayerPrefs.GetInt("Level", 1);

        ZaynCompleteGame.Instance.currentHealth =
            PlayerPrefs.GetInt(
                "Health",
                ZaynCompleteGame.Instance.maxHealth
            );
    }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskMasterApp());
}

class AppTheme {
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceAlt = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);
  static const Color primary = Color(0xFF1F6FEB);
  static const Color primaryLight = Color(0xFF58A6FF);
  static const Color success = Color(0xFF2EA043);
  static const Color danger = Color(0xFFCF222E);
  static const Color warning = Color(0xFFD29922);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textMuted = Color(0xFF8B949E);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: primaryLight,
          surface: surface,
          error: danger,
          onPrimary: Colors.white,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryLight, width: 1.5),
          ),
        ),
      );
}

class Task {
  final String id;
  String title;
  bool done;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.done = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        done: json['done'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using System.Collections.Generic;

public class ZaynCompleteGame : MonoBehaviour
{
    public static ZaynCompleteGame Instance;

    [Header("PLAYER")]
    public CharacterController controller;
    public Transform playerCamera;
    public Transform attackPoint;
    public Transform firePoint;

    [Header("MOVEMENT")]
    public float moveSpeed = 6f;
    public float gravity = -20f;
    public float jumpHeight = 2f;
    public float rotationSpeed = 12f;
    public float dashSpeed = 18f;
    public float dashDuration = 0.25f;

    [Header("HEALTH")]
    public int maxHealth = 100;
    public int currentHealth;

    [Header("ENERGY")]
    public int maxEnergy = 100;
    public int currentEnergy;
    public int energyCost = 20;

    [Header("COMBAT")]
    public int meleeDamage = 25;
    public int energyDamage = 35;
    public float attackRange = 2f;
    public float attackCooldown = 0.5f;
    public float energyCooldown = 1f;
    public LayerMask enemyLayer;
    public GameObject energyPrefab;

    [Header("SHIELD")]
    public bool shieldActive;
    public float shieldDuration = 3f;
    public float shieldCooldown = 8f;

    [Header("ULTIMATE")]
    public int ultimateDamage = 100;
    public float ultimateCooldown = 15f;

    [Header("MISSION")]
    public int enemiesRequired = 5;
    public int enemiesDefeated;
    public bool missionCompleted;

    [Header("CURRENCY")]
    public int coins;
    public int experience;
    public int level = 1;

    [Header("UI")]
    public Slider healthBar;
    public Slider energyBar;
    public Text healthText;
    public Text energyText;
    public Text coinsText;
    public Text missionText;

    [Header("ENEMIES")]
    public GameObject enemyPrefab;
    public GameObject fastEnemyPrefab;
    public GameObject strongEnemyPrefab;
    public Transform[] enemySpawnPoints;

    [Header("BOSS")]
    public GameObject bossPrefab;
    public Transform bossSpawnPoint;
    public bool bossSpawned;

    private Vector2 moveInput;
    private Vector3 velocity;

    private bool attackPressed;
    private bool energyPressed;
    private bool jumpPressed;
    private bool dashPressed;
    private bool shieldPressed;
    private bool ultimatePressed;

    private float nextAttackTime;
    private float nextEnergyTime;
    private float nextShieldTime;
    private float nextUltimateTime;

    private bool isDashing;
    private float dashTimer;
    private bool isDead;

    void Awake()
    {
        Instance = this;
    }

    void Start()
    {
        if (controller == null)
            controller = GetComponent<CharacterController>();

        currentHealth = maxHealth;
        currentEnergy = maxEnergy;

        SpawnMissionEnemies();
        UpdateUI();
    }

    void Update()
    {
        if (isDead)
            return;

        HandleMovement();
        HandleButtons();
        RegenerateEnergy();
        UpdateUI();
    }

    void HandleMovement()
    {
        Vector3 direction = new Vector3(
            moveInput.x,
            0f,
            moveInput.y
        );

#if UNITY_EDITOR
        direction += new Vector3(
            Input.GetAxis("Horizontal"),
            0f,
            Input.GetAxis("Vertical")
        );

        if (Input.GetButtonDown("Jump"))
            jumpPressed = true;

        if (Input.GetKeyDown(KeyCode.LeftShift))
            dashPressed = true;

        if (Input.GetKeyDown(KeyCode.Q))
            shieldPressed = true;

        if (Input.GetKeyDown(KeyCode.E))
            ultimatePressed = true;

        if (Input.GetMouseButtonDown(0))
            attackPressed = true;

        if (Input.GetMouseButtonDown(1))
            energyPressed = true;
#endif

        if (isDashing)
        {
            controller.Move(
                transform.forward *
                dashSpeed *
                Time.deltaTime
            );

            dashTimer -= Time.deltaTime;

            if (dashTimer <= 0f)
                isDashing = false;
        }
        else if (direction.magnitude > 0.1f)
        {
            if (playerCamera != null)
            {
                direction =
                    playerCamera.TransformDirection(direction);

                direction.y = 0f;
            }

            direction.Normalize();

            controller.Move(
                direction *
                moveSpeed *
                Time.deltaTime
            );

            Quaternion targetRotation =
                Quaternion.LookRotation(direction);

            transform.rotation =
                Quaternion.Slerp(
                    transform.rotation,
                    targetRotation,
                    rotationSpeed * Time.deltaTime
                );
        }

        if (
            controller.isGrounded &&
            velocity.y < 0f
        )
        {
            velocity.y = -2f;
        }

        if (
            jumpPressed &&
            controller.isGrounded
        )
        {
            velocity.y =
                Mathf.Sqrt(
                    jumpHeight *
                    -2f *
                    gravity
                );

            jumpPressed = false;
        }

        velocity.y += gravity * Time.deltaTime;

        controller.Move(
            velocity * Time.deltaTime
        );
    }

    void HandleButtons()
    {
        if (attackPressed)
        {
            MeleeAttack();
            attackPressed = false;
        }

        if (energyPressed)
        {
            EnergyAttack();
            energyPressed = false;
        }

        if (dashPressed)
        {
            Dash();
            dashPressed = false;
        }

        if (shieldPressed)
        {
            ActivateShield();
            shieldPressed = false;
        }

        if (ultimatePressed)
        {
            UltimateAttack();
            ultimatePressed = false;
        }
    }

    public void SetMove(Vector2 value)
    {
        moveInput = value;
    }

    public void AttackButton()
    {
        attackPressed = true;
    }

    public void EnergyButton()
    {
        energyPressed = true;
    }

    public void JumpButton()
    {
        jumpPressed = true;
    }

    public void DashButton()
    {
        dashPressed = true;
    }

    public void ShieldButton()
    {
        shieldPressed = true;
    }

    public void UltimateButton()
    {
        ultimatePressed = true;
    }

    void MeleeAttack()
    {
        if (Time.time < nextAttackTime)
            return;

        nextAttackTime =
            Time.time + attackCooldown;

        if (attackPoint == null)
            return;

        Collider[] hits =
            Physics.OverlapSphere(
                attackPoint.position,
                attackRange,
                enemyLayer
            );

        foreach (Collider hit in hits)
        {
            ZaynEnemy enemy =
                hit.GetComponentInParent<ZaynEnemy>();

            if (enemy != null)
                enemy.TakeDamage(meleeDamage);
        }
    }

    void EnergyAttack()
    {
        if (Time.time < nextEnergyTime)
            return;

        if (currentEnergy < energyCost)
            return;

        currentEnergy -= energyCost;

        nextEnergyTime =
            Time.time + energyCooldown;

        if (
            energyPrefab != null &&
            firePoint != null
        )
        {
            GameObject projectile =
                Instantiate(
                    energyPrefab,
                    firePoint.position,
                    firePoint.rotation
                );

            ZaynProjectile projectileScript =
                projectile.GetComponent<ZaynProjectile>();

            if (projectileScript == null)
                projectileScript =
                    projectile.AddComponent<ZaynProjectile>();

            projectileScript.damage =
                energyDamage;
        }
    }

    void Dash()
    {
        if (isDashing)
            return;

        isDashing = true;
        dashTimer = dashDuration;
    }

    void ActivateShield()
    {
        if (Time.time < nextShieldTime)
            return;

        shieldActive = true;

        nextShieldTime =
            Time.time + shieldCooldown;

        Invoke(
            nameof(DisableShield),
            shieldDuration
        );
    }

    void DisableShield()
    {
        shieldActive = false;
    }

    void UltimateAttack()
    {
        if (Time.time < nextUltimateTime)
            return;

        if (currentEnergy < 50)
            return;

        currentEnergy -= 50;

        nextUltimateTime =
            Time.time + ultimateCooldown;

        Collider[] enemies =
            Physics.OverlapSphere(
                transform.position,
                8f,
                enemyLayer
            );

        foreach (Collider hit in enemies)
        {
            ZaynEnemy enemy =
                hit.GetComponentInParent<ZaynEnemy>();

            if (enemy != null)
                enemy.TakeDamage(ultimateDamage);
        }
    }

    public void TakeDamage(int damage)
    {
        if (isDead)
            return;

        if (shieldActive)
            damage = Mathf.Max(1, damage / 4);

        currentHealth -= damage;

        currentHealth =
            Mathf.Clamp(
                currentHealth,
                0,
                maxHealth
            );

        if (currentHealth <= 0)
            Die();
    }

    public void Heal(int amount)
    {
        currentHealth =
            Mathf.Min(
                currentHealth + amount,
                maxHealth
            );
    }

    void Die()
    {
        isDead = true;

        Invoke(
            nameof(RestartPlayer),
            3f
        );
    }

    void RestartPlayer()
    {
        isDead = false;
        currentHealth = maxHealth;
        currentEnergy = maxEnergy;
    }

    void RegenerateEnergy()
    {
        if (currentEnergy < maxEnergy)
        {
            currentEnergy +=
                Mathf.CeilToInt(
                    10f * Time.deltaTime
                );

            currentEnergy =
                Mathf.Clamp(
                    currentEnergy,
                    0,
                    maxEnergy
                );
        }
    }

    public void EnemyDefeated(
        int rewardCoins,
        int rewardXP
    )
    {
        enemiesDefeated++;

        coins += rewardCoins;
        experience += rewardXP;

        CheckLevel();

        if (
            !missionCompleted &&
            enemiesDefeated >= enemiesRequired
        )
        {
            CompleteMission();
        }
    }

    void CompleteMission()
    {
        missionCompleted = true;

        if (!bossSpawned)
        {
            bossSpawned = true;

            if (
                bossPrefab != null &&
                bossSpawnPoint != null
            )
            {
                Instantiate(
                    bossPrefab,
                    bossSpawnPoint.position,
                    bossSpawnPoint.rotation
                );
            }
        }
    }

    void CheckLevel()
    {
        int requiredXP = level * 100;

        if (experience >= requiredXP)
        {
            experience -= requiredXP;
            level++;

            maxHealth += 20;
            maxEnergy += 10;

            currentHealth = maxHealth;
            currentEnergy = maxEnergy;
        }
    }

    void SpawnMissionEnemies()
    {
        if (
            enemyPrefab == null ||
            enemySpawnPoints == null
        )
            return;

        for (
            int i = 0;
            i < enemiesRequired;
            i++
        )
        {
            Transform point =
                enemySpawnPoints[
                    i % enemySpawnPoints.Length
                ];

            Instantiate(
                enemyPrefab,
                point.position,
                point.rotation
            );
        }
    }

    void UpdateUI()
    {
        if (healthBar != null)
        {
            healthBar.maxValue = maxHealth;
            healthBar.value = currentHealth;
        }

        if (energyBar != null)
        {
            energyBar.maxValue = maxEnergy;
            energyBar.value = currentEnergy;
        }

        if (healthText != null)
        {
            healthText.text =
                "HP " +
                currentHealth +
                "/" +
                maxHealth;
        }

        if (energyText != null)
        {
            energyText.text =
                "⚡ " +
                currentEnergy +
                "/" +
                maxEnergy;
        }

        if (coinsText != null)
        {
            coinsText.text =
                "🪙 " + coins;
        }

        if (missionText != null)
        {
            if (!missionCompleted)
            {
                missionText.text =
                    "اهزم جنود الظلام " +
                    enemiesDefeated +
                    "/" +
                    enemiesRequired;
            }
            else
            {
                missionText.text =
                    "اهزم حارس الشق";
            }
        }
    }

    void OnDrawGizmosSelected()
    {
        if (attackPoint != null)
        {
            Gizmos.DrawWireSphere(
                attackPoint.position,
                attackRange
            );
        }
    }
}

public class ZaynEnemy : MonoBehaviour
{
    public int maxHealth = 100;
    public int currentHealth;

    public int damage = 10;
    public int rewardCoins = 10;
    public int rewardXP = 20;

    public float speed = 3f;
    public float detectionRange = 15f;
    public float attackRange = 2f;
    public float attackCooldown = 1.5f;

    public bool isBoss;

    private Transform player;
    private float nextAttack;
    private bool dead;

    void Start()
    {
        currentHealth = maxHealth;

        if (ZaynCompleteGame.Instance != null)
            player =
                ZaynCompleteGame.Instance.transform;
    }

    void Update()
    {
        if (dead || player == null)
            return;

        float distance =
            Vector3.Distance(
                transform.position,
                player.position
            );

        if (distance > detectionRange)
            return;

        if (distance > attackRange)
        {
            Vector3 target =
                new Vector3(
                    player.position.x,
                    transform.position.y,
                    player.position.z
                );

            transform.LookAt(target);

            transform.position =
                Vector3.MoveTowards(
                    transform.position,
                    target,
                    speed * Time.deltaTime
                );
        }
        else
        {
            Attack();
        }
    }

    void Attack()
    {
        if (Time.time < nextAttack)
            return;

        if (ZaynCompleteGame.Instance != null)
        {
            ZaynCompleteGame.Instance
                .TakeDamage(damage);
        }

        nextAttack =
            Time.time + attackCooldown;
    }

    public void TakeDamage(int amount)
    {
        if (dead)
            return;

        currentHealth -= amount;

        if (currentHealth <= 0)
            Die();
    }

    void Die()
    {
        dead = true;

        if (ZaynCompleteGame.Instance != null)
        {
            ZaynCompleteGame.Instance.EnemyDefeated(
                rewardCoins,
                rewardXP
            );
        }

        Destroy(gameObject);
    }
}

public class ZaynBoss : MonoBehaviour
{
    public int maxHealth = 500;
    public int currentHealth;

    public int damage = 25;
    public float speed = 4f;
    public float attackRange = 3f;

    public GameObject minionPrefab;
    public Transform[] spawnPoints;

    private Transform player;
    private float nextAttack;
    private bool phaseTwo;
    private bool dead;

    void Start()
    {
        currentHealth = maxHealth;

        if (ZaynCompleteGame.Instance != null)
            player =
                ZaynCompleteGame.Instance.transform;
    }

    void Update()
    {
        if (dead || player == null)
            return;

        float distance =
            Vector3.Distance(
                transform.position,
                player.position
            );

        if (
            !phaseTwo &&
            currentHealth <= maxHealth / 2
        )
        {
            phaseTwo = true;
            speed = 6f;
            damage = 40;
            SpawnMinions();
        }

        if (distance > attackRange)
        {
            transform.LookAt(
                new Vector3(
                    player.position.x,
                    transform.position.y,
                    player.position.z
                )
            );

            transform.position =
                Vector3.MoveTowards(
                    transform.position,
                    player.position,
                    speed * Time.deltaTime
                );
        }
        else
        {
            BossAttack();
        }
    }

    void BossAttack()
    {
        if (Time.time < nextAttack)
            return;

        if (ZaynCompleteGame.Instance != null)
        {
            ZaynCompleteGame.Instance
                .TakeDamage(damage);
        }

        nextAttack =
            Time.time + 1.2f;
    }

    void SpawnMinions()
    {
        if (
            minionPrefab == null ||
            spawnPoints == null
        )
            return;

        foreach (Transform point in spawnPoints)
        {
            Instantiate(
                minionPrefab,
                point.position,
                point.rotation
            );
        }
    }

    public void TakeDamage(int amount)
    {
        if (dead)
            return;

        currentHealth -= amount;

        if (currentHealth <= 0)
        {
            dead = true;

            if (ZaynCompleteGame.Instance != null)
            {
                ZaynCompleteGame.Instance.coins += 100;
                ZaynCompleteGame.Instance.experience += 200;
            }

            Destroy(gameObject);
        }
    }
}

public class ZaynProjectile : MonoBehaviour
{
    public float speed = 20f;
    public int damage = 35;
    public float lifeTime = 4f;

    void Start()
    {
        Destroy(gameObject, lifeTime);
    }

    void Update()
    {
        transform.position +=
            transform.forward *
            speed *
            Time.deltaTime;
    }

    void OnTriggerEnter(Collider other)
    {
        ZaynEnemy enemy =
            other.GetComponentInParent<ZaynEnemy>();

        if (enemy != null)
        {
            enemy.TakeDamage(damage);
            Destroy(gameObject);
            return;
        }

        ZaynBoss boss =
            other.GetComponentInParent<ZaynBoss>();

        if (boss != null)
        {
            boss.TakeDamage(damage);
            Destroy(gameObject);
        }
    }
}

public class ZaynMobileJoystick :
    MonoBehaviour,
    IPointerDownHandler,
    IDragHandler,
    IPointerUpHandler
{
    public RectTransform background;
    public RectTransform handle;
    public float radius = 100f;

    public void OnPointerDown(
        PointerEventData eventData
    )
    {
        OnDrag(eventData);
    }

    public void OnDrag(
        PointerEventData eventData
    )
    {
        if (
            background == null ||
            handle == null ||
            ZaynCompleteGame.Instance == null
        )
            return;

        Vector2 position;

        RectTransformUtility
            .ScreenPointToLocalPointInRectangle(
                background,
                eventData.position,
                eventData.pressEventCamera,
                out position
            );

        Vector2 input =
            new Vector2(
                position.x /
                (background.sizeDelta.x / 2f),

                position.y /
                (background.sizeDelta.y / 2f)
            );

        input =
            input.magnitude > 1f
            ? input.normalized
            : input;

        handle.anchoredPosition =
            input * radius;

        ZaynCompleteGame.Instance
            .SetMove(input);
    }

    public void OnPointerUp(
        PointerEventData eventData
    )
    {
        if (handle != null)
            handle.anchoredPosition =
                Vector2.zero;

        if (ZaynCompleteGame.Instance != null)
        {
            ZaynCompleteGame.Instance
                .SetMove(Vector2.zero);
        }
    }
}

public class ZaynCheckpoint : MonoBehaviour
{
    public Transform respawnPoint;

    void OnTriggerEnter(Collider other)
    {
        if (!other.CompareTag("Player"))
            return;

        PlayerPrefs.SetFloat(
            "ZaynX",
            respawnPoint.position.x
        );

        PlayerPrefs.SetFloat(
            "ZaynY",
            respawnPoint.position.y
        );

        PlayerPrefs.SetFloat(
            "ZaynZ",
            respawnPoint.position.z
        );

        PlayerPrefs.Save();
    }
}

public class ZaynSaveSystem : MonoBehaviour
{
    public void SaveGame()
    {
        if (ZaynCompleteGame.Instance == null)
            return;

        PlayerPrefs.SetInt(
            "Coins",
            ZaynCompleteGame.Instance.coins
        );

        PlayerPrefs.SetInt(
            "Experience",
            ZaynCompleteGame.Instance.experience
        );

        PlayerPrefs.SetInt(
            "Level",
            ZaynCompleteGame.Instance.level
        );

        PlayerPrefs.SetInt(
            "Health",
            ZaynCompleteGame.Instance.currentHealth
        );

        PlayerPrefs.Save();
    }

    public void LoadGame()
    {
        if (ZaynCompleteGame.Instance == null)
            return;

        ZaynCompleteGame.Instance.coins =
            PlayerPrefs.GetInt("Coins", 0);

        ZaynCompleteGame.Instance.experience =
            PlayerPrefs.GetInt("Experience", 0);

        ZaynCompleteGame.Instance.level =
            PlayerPrefs.GetInt("Level", 1);

        ZaynCompleteGame.Instance.currentHealth =
            PlayerPrefs.GetInt(
                "Health",
                ZaynCompleteGame.Instance.maxHealth
            );
    }
}

class TaskMasterApp extends StatelessWidget {
  const TaskMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مقمرات زين',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const TaskHomePage(),
    );
  }
}

enum TaskFilter { all, active, completed }

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage>
    with SingleTickerProviderStateMixin {
  static const String _storageKey = 'klencod_tasks_v1';

  final List<Task> _tasks = [];
  final TextEditingController _searchController = TextEditingController();
  TaskFilter _filter = TaskFilter.all;
  String _searchQuery = '';
  bool _loading = true;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadTasks();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final list = jsonDecode(data) as List<dynamic>;
        _tasks.clear();
        _tasks.addAll(list.map((e) => Task.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
    setState(() => _loading = false);
    _fadeController.forward();
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }

  void _addTask(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _tasks.insert(
        0,
        Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: trimmed,
          createdAt: DateTime.now(),
        ),
      );
    });
    _saveTasks();
    HapticFeedback.lightImpact();
    _showSnack('تمت إضافة المهمة', success: true);
  }

  void _toggleTask(Task task) {
    setState(() => task.done = !task.done);
    _saveTasks();
    HapticFeedback.selectionClick();
  }

  void _deleteTask(Task task) {
    final index = _tasks.indexOf(task);
    if (index == -1) return;
    setState(() => _tasks.removeAt(index));
    _saveTasks();
    _showSnack(
      'تم حذف المهمة',
      actionLabel: 'تراجع',
      onAction: () {
        setState(() => _tasks.insert(index, task));
        _saveTasks();
      },
    );
  }

  void _clearCompleted() {
    final completed = _tasks.where((t) => t.done).toList();
    if (completed.isEmpty) {
      _showSnack('لا توجد مهام مكتملة');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        ctx,
        title: 'حذف المهام المكتملة',
        message: 'سيتم حذف ${completed.length} مهمة مكتملة. لا يمكن التراجع.',
        onConfirm: () {
          setState(() => _tasks.removeWhere((t) => t.done));
          _saveTasks();
          Navigator.pop(ctx);
          _showSnack('تم حذف ${completed.length} مهمة', success: true);
        },
      ),
    );
  }

  void _showSnack(String message,
      {String? actionLabel, VoidCallback? onAction, bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: success ? AppTheme.success : AppTheme.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceAlt,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppTheme.primaryLight,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  Widget _buildConfirmDialog(
    BuildContext ctx, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      content: Text(message, style: const TextStyle(color: AppTheme.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text('تأكيد',
              style: TextStyle(
                  color: AppTheme.danger, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _openAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.add_task_rounded, color: AppTheme.primaryLight),
            SizedBox(width: 10),
            Text('مهمة جديدة',
                style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            _addTask(v);
            Navigator.pop(ctx);
          },
          decoration: const InputDecoration(
            hintText: 'اكتب المهمة...',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            onPressed: () {
              _addTask(controller.text);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  List<Task> get _visibleTasks {
    Iterable<Task> result = _tasks;
    if (_filter == TaskFilter.active) {
      result = result.where((t) => !t.done);
    } else if (_filter == TaskFilter.completed) {
      result = result.where((t) => t.done);
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) => t.title.toLowerCase().contains(q));
    }
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryLight),
        ),
      );
    }

    final visible = _visibleTasks;
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.done).length;
    final active = total - completed;
    final progress = total == 0 ? 0.0 : completed / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مقمرات زين'),
        actions: [
          if (completed > 0)
            IconButton(
              tooltip: 'حذف المكتملة',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearCompleted,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('مهمة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildHeader(total, completed, active, progress),
          _buildSearchBar(),
          _buildFilters(total, active, completed),
          Expanded(
            child: visible.isEmpty
                ? _buildEmptyState()
                : _buildTaskList(visible),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int total, int completed, int active, double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F6FEB), Color(0xFF0D419D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  total == 0 ? 'لا توجد مهام بعد' : 'مهامك',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statChip('الإجمالي', total, Colors.white),
                _statChip('نشطة', active, AppTheme.warning),
                _statChip('مكتملة', completed, AppTheme.success),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% إنجاز',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'بحث في المهام...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppTheme.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilters(int total, int active, int completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _filterChip('الكل', TaskFilter.all, total),
          const SizedBox(width: 8),
          _filterChip('نشطة', TaskFilter.active, active),
          const SizedBox(width: 8),
          _filterChip('مكتملة', TaskFilter.completed, completed),
        ],
      ),
    );
  }

  Widget _filterChip(String label, TaskFilter filter, int count) {
    final selected = _filter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryLight : AppTheme.border,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white70 : AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> visible) {
    return FadeTransition(
      opacity: _fadeController,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final task = visible[index];
          return _buildTaskItem(task);
        },
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_rounded,
            color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        _deleteTask(task);
        return false;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: task.done
                ? AppTheme.success.withOpacity(0.4)
                : AppTheme.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleTask(task),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: task.done
                          ? AppTheme.success
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: task.done
                            ? AppTheme.success
                            : AppTheme.textMuted,
                        width: 2,
                      ),
                    ),
                    child: task.done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: task.done
                                ? AppTheme.textMuted
                                : AppTheme.textPrimary,
                            fontSize: 15,
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(task.createdAt),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.textMuted),
                    onPressed: () => _deleteTask(task),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    return 'منذ ${diff.inDays} يوم';
  }

  Widget _buildEmptyState() {
    final String message;
    final IconData icon;
    if (_searchQuery.isNotEmpty) {
      message = 'لا توجد نتائج للبحث';
      icon = Icons.search_off_rounded;
    } else if (_filter == TaskFilter.completed) {
      message = 'لا توجد مهام مكتملة بعد';
      icon = Icons.check_circle_outline_rounded;
    } else if (_filter == TaskFilter.active) {
      message = 'كل المهام مكتملة!';
      icon = Icons.celebration_rounded;
    } else {
      message = 'ابدأ بإضافة مهمتك الأولى';
      icon = Icons.playlist_add_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 56, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'استخدم الزر أدناه للبدء',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}