/*
 * Copyright 2017 Kirill Rodriguez
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Modified for Flutter FFI integration.
 */

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <time.h>
#include <math.h>

/* ============================================================================
 * TYPES AND DECLARATIONS (from algx.h)
 * ============================================================================ */

// (CONSTRx(RxC))xN
#define RIDX(C,R) ((C)*s->ne2 + (R))
#define R_SLNS(C, R) s->r[RIDX(C, R)]

// (RxCxN)xCONSTR
#define CIDX(R, C) (((R) << 2) | (C))
#define C_CNSTR(R, C) s->c[CIDX(R, C)]

typedef uint_fast8_t val_t;
typedef int_fast32_t sz_t;

struct _cov_t;
struct _sol_t;

typedef enum { FORWARD, BACKTRACK } ACTION;

typedef struct _sd_t {
  // general
  sz_t n, ne2, ne3, ne4;
  val_t *table;
  // constraint table
  sz_t w, h, wy;
  sz_t *r, *c;
  // solver
  sz_t no_hints, no_vars;
  int_fast32_t i;
  ACTION action;
  struct _cov_t *cov;
  struct _sol_t *soln;
  val_t *buf;
  // difficulty tracking
  sz_t forward_count;
  sz_t backtrack_count;
} sd_t;

typedef enum { ROWCOL, BOXNUM, ROWNUM, COLNUM, NO_CONSTR } CONSTRAINTS;

typedef enum { INVALID, COMPLETE, MULTIPLE } RESULT;

typedef struct _cov_t {
  val_t *row, *col;
  sz_t *colfail, *colchoice;
} cov_t;

typedef struct _sol_t {
  sz_t *row, *col;
} sol_t;

#define MINUNDEF (s->ne2 + 1)
typedef struct _min_t {
  val_t min;
  sz_t min_col;
  sz_t fail_rate;
  sz_t choice_rate;
} min_t;

static const sz_t UNDEF_SIZE = -1;

static inline void sd_update(const sd_t *s, sz_t r, ACTION flag);
static inline void sd_update_min(sd_t *s, sz_t r, ACTION flag, min_t *m);
static inline void sd_forward(sd_t *s, sz_t r, sz_t c);
static inline void sd_forward_min(sd_t *s, sz_t r, sz_t c, min_t *m);
static inline void sd_backtrack(const sd_t *s, sz_t r, sz_t c);

/* ============================================================================
 * SOLVER IMPLEMENTATION (from algx.c)
 * ============================================================================ */

static sd_t *make_sd(sz_t n, val_t *table) {
attributes:;
  sd_t *s=malloc(sizeof(sd_t));assert(s != NULL);
  s->n=n, s->ne2=n*n, s->ne3=s->ne2*n, s->ne4=s->ne3 * n;
  s->table=malloc(sizeof(val_t)*s->ne4),assert(s->table!=NULL);
  memcpy(s->table, table, sizeof(val_t) * s->ne4);
  s->forward_count=0, s->backtrack_count=0;
// constraint table
  s->w = s->ne4 * NO_CONSTR;
  s->h = s->ne4 * s->ne2;
col:;
  s->c=malloc(sizeof(sz_t)*s->h*NO_CONSTR),assert(s->c!=NULL);
  for(sz_t r = 0; r < s->ne2; ++r) {
    for(sz_t c = 0; c < s->ne2; ++c) {
      for(sz_t v = 0; v < s->ne2; ++v) {
        sz_t *it = &C_CNSTR(r * s->ne4 + c * s->ne2 + v, 0);
        it[ROWCOL] = s->ne4 * ROWCOL + s->ne2 * r + c,
        it[BOXNUM] = s->ne4 * BOXNUM + (r / s->n * s->n + c / s->n) * s->ne2 + v,
        it[ROWNUM] = s->ne4 * ROWNUM + s->ne2 * r + v,
        it[COLNUM] = s->ne4 * COLNUM + s->ne2 * c + v;
      }
    }
  }
row:;
  val_t *mem = calloc(s->w, sizeof(val_t));
  s->r=malloc(sizeof(sz_t)*s->w*s->ne2),assert(s->r!=NULL);
  for(sz_t r = 0; r < s->h; ++r) {
    for(sz_t c = 0; c < NO_CONSTR; ++c) {
      sz_t i = C_CNSTR(r, c);
      assert(0 <= i && i < s->w);
      R_SLNS(i,mem[i]) = r, ++mem[i];
    }
  }
  free(mem);
// solver
cov:;
  size_t
    cov_header=sizeof(cov_t),
    cov_row=sizeof(val_t)*s->h,
    cov_col=sizeof(val_t)*s->w,
    cov_colfail=sizeof(sz_t)*s->w,
    cov_colchoice=sizeof(sz_t)*s->w;
  s->cov=malloc(cov_header+cov_row+cov_col+cov_colfail+cov_colchoice),assert(s->cov != NULL);
  void *first = (void *)s->cov;
  s->cov->row = (first+=cov_header);
  s->cov->col = (first+=cov_row);
  s->cov->colfail = (first+=cov_col);
  s->cov->colchoice = (first+=cov_colfail);
soln:;
  size_t
    soln_header = sizeof(sol_t),
    soln_row = sizeof(sz_t) * s->ne4,
    soln_col = sizeof(sz_t) * s->ne4;
  s->soln=malloc(soln_header+soln_row+soln_col),assert(s->soln != NULL);
  first = (void *)s->soln;
  s->soln->row = (first+=soln_header);
  s->soln->col = (first+=soln_row);
buf:;
  s->buf=malloc(sizeof(val_t)*s->ne4),assert(s->buf != NULL);
ret:;
  return s;
}

static void free_sd(sd_t *s) {
  free(s->table);
  free(s->r);
  free(s->c);
  if(s->cov!=NULL)free(s->cov);
  if(s->soln!=NULL)free(s->soln);
  if(s->buf!=NULL)free(s->buf);
  free(s);
}

static inline min_t default_min(const sd_t *s) {
  return (min_t){
    .min=MINUNDEF,
    .min_col=0,
    .fail_rate=0,
    .choice_rate=0
  };
}

static inline void sd_update(const sd_t *s, sz_t r, ACTION flag) {
  const static val_t LBIT = 1 << (CHAR_BIT * sizeof(val_t) - 1);
  for(sz_t ic = 0; ic < NO_CONSTR; ++ic)s->cov->col[C_CNSTR(r, ic)] ^= LBIT;
  for(sz_t ic = 0; ic < NO_CONSTR; ++ic)
    if(flag==FORWARD)sd_forward((sd_t*)s,r,ic);else
      sd_backtrack(s,r,ic);
}

static inline void sd_update_min(sd_t *s, sz_t r, ACTION flag, min_t *m) {
  *m = default_min(s);
  const static val_t LBIT = 1 << (CHAR_BIT * sizeof(val_t) - 1);
  for(sz_t ic = 0; ic < NO_CONSTR; ++ic)s->cov->col[C_CNSTR(r, ic)] ^= LBIT;
  for(sz_t ic = 0; ic < NO_CONSTR; ++ic)
    if(flag==FORWARD)sd_forward_min(s,r,ic,m);else
      sd_backtrack(s,r,ic);
}

static inline void sd_forward(sd_t *s, sz_t r, sz_t ic) {
  assert(ic < NO_CONSTR);
  const sz_t c = C_CNSTR(r, ic);assert(c < s->w);
  ++s->forward_count;
  for(sz_t ir = 0; ir < s->ne2; ++ir) {
    sz_t rr = R_SLNS(c, ir);assert(rr < s->h);
    if(s->cov->row[rr]++ != 0)continue;
    for(sz_t ic2 = 0; ic2 < NO_CONSTR; ++ic2) {
      sz_t cc = C_CNSTR(rr, ic2);assert(cc < s->w);
      --s->cov->col[cc];
    }
  }
}

static inline void sd_forward_min(sd_t *s, sz_t r, sz_t ic, min_t *m) {
  assert(ic < NO_CONSTR);
  const sz_t c = C_CNSTR(r, ic);assert(c < s->w);
  ++s->forward_count;
  for(sz_t ir = 0; ir < s->ne2; ++ir) {
    sz_t rr = R_SLNS(c, ir);assert(rr < s->h);
    if(s->cov->row[rr]++ != 0)continue;
    for(sz_t ic2 = 0; ic2 < NO_CONSTR; ++ic2) {
      sz_t cc = C_CNSTR(rr, ic2);assert(cc < s->w);
      --s->cov->col[cc];
      if(s->cov->col[cc] < m->min || (s->cov->col[cc] == m->min && s->cov->colfail[cc] > m->fail_rate))
        m->min=s->cov->col[cc],m->min_col=cc,
        m->fail_rate=s->cov->colfail[cc],
        m->choice_rate=s->cov->colchoice[cc];
    }
  }
}

static inline void sd_backtrack(const sd_t *s, sz_t r, sz_t ic) {
  assert(ic < NO_CONSTR);
  sz_t c = C_CNSTR(r, ic); assert(c < s->w);
  ++((sd_t*)s)->backtrack_count;
  for(sz_t ir = 0; ir < s->ne2; ++ir) {
    sz_t rr = R_SLNS(c, ir);
    assert(rr < s->h);
    --s->cov->row[rr];
    assert(0 <= s->cov->row[rr] && s->cov->row[rr] <= NO_CONSTR);
    if(s->cov->row[rr] != ROWCOL)continue;
    sz_t *it = &C_CNSTR(rr, 0);
    ++s->cov->col[it[ROWCOL]], ++s->cov->col[it[BOXNUM]],
    ++s->cov->col[it[ROWNUM]], ++s->cov->col[it[COLNUM]];
  }
}

static inline bool check_sd(sd_t *s) {
  val_t *check = calloc(s->ne2*3, sizeof(val_t));
  assert(check != NULL);
  for(sz_t i = 0; i < s->ne2; ++i) {
    memset(check, 0x00, s->ne2 * 3 * sizeof(val_t));
    for(sz_t j = 0; j < s->ne2; ++j) {
      sz_t pos[3]={i*s->ne2+j, j*s->ne2+i, (i/s->n*s->n+j/s->n)*s->ne2+(i%s->n)*s->n+j%s->n};
      for(int k = 0; k < 3; ++k) {
        val_t t=s->table[pos[k]];if(!t)continue;
        val_t*chk=&check[k*s->ne2+t-1]; if(*chk){free(check);return false;} *chk=true;
      }
    }
  }
  free(check);
  return true;
}

static inline void sd_reset(sd_t *s) {
  s->no_hints=0;
  for(sz_t i=0;i<s->h;++i)s->cov->row[i]=ROWCOL;
  for(sz_t i=0;i<s->w;++i)s->cov->col[i]=s->ne2;
  for(sz_t i=0;i<s->w;++i)s->cov->colfail[i]=0;
  for(sz_t i=0;i<s->w;++i)s->cov->colchoice[i]=0;
  s->i=0,s->action=FORWARD;
  s->forward_count=0,s->backtrack_count=0;
}

static inline void sd_forward_knowns(sd_t *s) {
  sd_reset(s);
  for(sz_t i = 0; i < s->ne4; ++i) {
    val_t t = s->table[i];
    if(t) {
      sd_update(s, i * s->ne2 + t - 1, FORWARD);
      ++s->no_hints;
    }
    s->soln->row[i]=s->soln->col[i]=UNDEF_SIZE, s->buf[i]=t;
  }
  s->no_vars = s->ne4 - s->no_hints;
}

static RESULT solve_sd(sd_t *s) {
  RESULT res = INVALID;
  if(!check_sd(s))return res=INVALID;
presetup:;
  sd_forward_knowns(s);
  min_t m = default_min(s);
  min_t m2 = default_min(s);
  (void)m2; // unused but kept for compatibility
iterate_unknowns:;
  while(1) {
    while(s->i >= 0 && s->i < s->no_vars) {
      if(s->action == FORWARD) {
        s->soln->col[s->i] = m.min_col;
        if(m.min > 1) {
          for(sz_t c = 0; c < s->w; ++c) {
            if(s->cov->col[c] < m.min || (s->cov->col[c] == m.min && s->cov->colfail[c] > m.fail_rate)) {
              m.min=s->cov->col[c],m.min_col=c,
              m.fail_rate=s->cov->colfail[c],
              m.choice_rate=s->cov->colchoice[c],
              s->soln->col[s->i]=c;if(m.min<2)break;
            }
          }
        } else if(m.min == MINUNDEF) {
          s->action = BACKTRACK,
          s->cov->colfail[m.min_col]=s->cov->colchoice[m.min_col],
          s->soln->row[s->i]=UNDEF_SIZE,
          --s->i;
        }
      }
      assert(s->i >= -1);
      const int_fast32_t ii = (s->i == -1) ? 0 : s->i;
      const sz_t cc = s->soln->col[ii];
      sz_t cr = s->soln->row[ii];
      assert(cc != UNDEF_SIZE && cc < s->h && (cr == UNDEF_SIZE || cr < s->w));
      if(s->action == BACKTRACK && cr != UNDEF_SIZE)
        s->cov->colfail[cc]=s->cov->colchoice[cc],
        sd_update(s, R_SLNS(cc, cr), BACKTRACK);
      cr = (cr == UNDEF_SIZE) ? 0 : cr + 1;
      while(cr < s->ne2) {
        if(s->cov->row[R_SLNS(cc, cr)] == 0)break;
        ++cr;
      }
      if(cr < s->ne2) {
        s->action=FORWARD;
        // experimental
        sz_t diff=(s->ne2/s->cov->col[cc]);diff=diff*diff*(s->no_vars-s->i)/s->w+1;
        s->cov->colchoice[cc] += diff,
        /* ++s->cov->colchoice[cc], */
        sd_update_min(s, R_SLNS(cc, cr), FORWARD, &m),
        s->soln->row[ii]=cr;
        ++s->i;
      } else {
        s->action=BACKTRACK,
        // experimental
        s->cov->colfail[cc] = s->cov->colchoice[cc] + s->i,
        /* s->cov->colfail[cc]=s->cov->colchoice[cc], */
        s->soln->row[ii]=UNDEF_SIZE;
        --s->i;
      }
    }
    if(s->i<0)break;
  change_res:;
    switch(res) {
      case INVALID:
        res = COMPLETE;
        for(sz_t j = 0; j < s->i; ++j) {
          sz_t r = R_SLNS(s->soln->col[j], s->soln->row[j]);
          assert(r < s->h);
          s->buf[r / s->ne2] = r % s->ne2 + 1;
        }
        memcpy(s->table, s->buf, sizeof(val_t) * s->ne4);
      break;
      case COMPLETE:
        res = MULTIPLE;
        goto endsolve;
      break;
      case MULTIPLE:
        assert(res != MULTIPLE);
      break;
    }
    --s->i,s->action=BACKTRACK;
  }
endsolve:
  return res;
}

/* ============================================================================
 * ISOMORPHIC TRANSFORMATIONS
 * ============================================================================ */

static uint32_t xorshift_state = 1;

static uint32_t xorshift32(void) {
  uint32_t x = xorshift_state;
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  xorshift_state = x;
  return x;
}

static void shuffle_array(sz_t *arr, sz_t len) {
  for(sz_t i = len - 1; i > 0; --i) {
    sz_t j = xorshift32() % (i + 1);
    sz_t tmp = arr[i];arr[i] = arr[j];arr[j] = tmp;
  }
}

/* Apply isomorphic transformation to puzzle:
 * - Shuffle rows within each band
 * - Shuffle columns within each stack
 * - Shuffle bands
 * - Shuffle stacks
 * - Relabel values
 */
static void apply_isomorphism(val_t *src, val_t *dst, sz_t n, uint32_t seed) {
  sz_t ne2 = n * n;
  xorshift_state = seed;

  // Create permutation arrays
  sz_t *band_perm = malloc(sizeof(sz_t) * n);
  sz_t *stack_perm = malloc(sizeof(sz_t) * n);
  sz_t *row_in_band = malloc(sizeof(sz_t) * n * n);
  sz_t *col_in_stack = malloc(sizeof(sz_t) * n * n);
  sz_t *value_perm = malloc(sizeof(sz_t) * (ne2 + 1));

  // Initialize and shuffle bands/stacks
  for(sz_t i = 0; i < n; ++i)band_perm[i] = i,stack_perm[i] = i;
  shuffle_array(band_perm, n);
  shuffle_array(stack_perm, n);

  // Initialize and shuffle rows within each band, cols within each stack
  for(sz_t b = 0; b < n; ++b) {
    for(sz_t i = 0; i < n; ++i)row_in_band[b * n + i] = i,col_in_stack[b * n + i] = i;
    shuffle_array(&row_in_band[b * n], n);
    shuffle_array(&col_in_stack[b * n], n);
  }

  // Initialize and shuffle value permutation (1-indexed)
  value_perm[0] = 0;
  for(sz_t i = 1; i <= ne2; ++i)value_perm[i] = i;
  shuffle_array(&value_perm[1], ne2);

  // Apply transformation
  for(sz_t row = 0; row < ne2; ++row) {
    sz_t src_band = row / n, src_row_in_band = row % n;
    sz_t dst_band = band_perm[src_band];
    sz_t dst_row_in_band = row_in_band[dst_band * n + src_row_in_band];
    sz_t dst_row = dst_band * n + dst_row_in_band;

    for(sz_t col = 0; col < ne2; ++col) {
      sz_t src_stack = col / n, src_col_in_stack = col % n;
      sz_t dst_stack = stack_perm[src_stack];
      sz_t dst_col_in_stack = col_in_stack[dst_stack * n + src_col_in_stack];
      sz_t dst_col = dst_stack * n + dst_col_in_stack;

      val_t val = src[row * ne2 + col];
      dst[dst_row * ne2 + dst_col] = value_perm[val];
    }
  }

  free(band_perm),free(stack_perm),free(row_in_band),free(col_in_stack),free(value_perm);
}

/* ============================================================================
 * DIFFICULTY ESTIMATION
 * ============================================================================ */

typedef struct {
  int32_t min_forwards;
  int32_t max_forwards;
  int32_t avg_forwards;
  int32_t min_backtracks;
  int32_t max_backtracks;
  int32_t avg_backtracks;
  int32_t samples;
} difficulty_stats_t;

/*
 * Estimate puzzle difficulty by solving multiple isomorphic versions.
 *
 * Parameters:
 *   table: puzzle values (0 = empty, 1-n^2 = filled)
 *   n: box size (2 for 4x4, 3 for 9x9, 4 for 16x16)
 *   num_samples: number of isomorphic versions to test
 *   out_stats: pointer to stats struct to fill
 *
 * Returns: 1 on success, 0 if puzzle is invalid/multiple solutions
 */
int estimate_difficulty(const uint8_t *table, int32_t n, int32_t num_samples,
                        difficulty_stats_t *out_stats) {
  sz_t ne4 = n * n * n * n;

  val_t *shuffled = malloc(sizeof(val_t) * ne4);
  assert(shuffled != NULL);

  int64_t total_forwards = 0, total_backtracks = 0;
  int32_t min_forwards = INT32_MAX, max_forwards = 0;
  int32_t min_backtracks = INT32_MAX, max_backtracks = 0;
  int32_t valid_samples = 0;

  uint32_t base_seed = (uint32_t)time(NULL);

  for(int32_t i = 0; i < num_samples; ++i) {
    apply_isomorphism((val_t *)table, shuffled, n, base_seed + i * 12345);

    sd_t *s = make_sd(n, shuffled);
    RESULT res = solve_sd(s);

    if(res == COMPLETE) {
      int32_t forwards = (int32_t)s->forward_count;
      int32_t backtracks = (int32_t)s->backtrack_count;

      total_forwards += forwards, total_backtracks += backtracks;
      if(forwards < min_forwards)min_forwards = forwards;
      if(forwards > max_forwards)max_forwards = forwards;
      if(backtracks < min_backtracks)min_backtracks = backtracks;
      if(backtracks > max_backtracks)max_backtracks = backtracks;
      valid_samples++;
    }

    free_sd(s);

    if(res == INVALID || res == MULTIPLE) {
      free(shuffled);
      out_stats->samples = 0;
      return 0;
    }
  }

  free(shuffled);

  if(valid_samples == 0) {
    out_stats->samples = 0;
    return 0;
  }

  out_stats->min_forwards = min_forwards;
  out_stats->max_forwards = max_forwards;
  out_stats->avg_forwards = (int32_t)(total_forwards / valid_samples);
  out_stats->min_backtracks = min_backtracks;
  out_stats->max_backtracks = max_backtracks;
  out_stats->avg_backtracks = (int32_t)(total_backtracks / valid_samples);
  out_stats->samples = valid_samples;

  return 1;
}

/* ============================================================================
 * GENERATOR (from sudoku_generator.c)
 * ============================================================================ */

typedef struct {
  sz_t n, ne2, ne4;
  sd_t *solver;
  val_t *table;
  RESULT status;
  sz_t no_vals;
} sdgen_t;

static sdgen_t sdgen_init(sz_t n) {
  sdgen_t s={.n=n,.ne2=n*n,.ne4=n*n*n*n,.solver=NULL,.table=malloc(sizeof(val_t)*n*n*n*n),
    .status=MULTIPLE,.no_vals=0};
  assert(s.table!=NULL),memset(s.table,0x00,sizeof(val_t)*s.ne4);
  return s;
}

static void sdgen_free(sdgen_t *s){if(s->solver)free_sd(s->solver);free(s->table);}

static void ord_arr(sz_t *arr, sz_t len){for(sz_t i=0;i<len;++i)arr[i]=i;}

static void gen_shuffle_arr(sz_t *arr, sz_t len) {
  for(sz_t i = 1; i < len; ++i) {
    sz_t j = xorshift32()%i;
    sz_t tmp;if(i!=j)tmp=arr[i],arr[i]=arr[j],arr[j]=tmp;
  }
}

static void sd_fill_box(sdgen_t *s, sz_t box_idx) {
  sz_t *arr = malloc(sizeof(sz_t) * s->ne2);
  ord_arr(arr, s->ne2),gen_shuffle_arr(arr, s->ne2);
  for(sz_t j=0;j<s->ne2;++j) {
    sz_t row = s->n * (box_idx / s->n) + (j / s->n);
    sz_t col = s->n * (box_idx % s->n) + (j % s->n);
    s->table[row * s->ne2 + col] = arr[j] + 1,++s->no_vals;
  }
  free(arr);
}

static void sd_init_diagonal_boxes(sdgen_t *s) {
  sz_t *ys = malloc(sizeof(sz_t) * s->n);
  ord_arr(ys, s->n),gen_shuffle_arr(ys, s->n);
  for(sz_t i = 0; i < s->n; ++i)sd_fill_box(s, ys[i] * s->n + i);
  free(ys);
}

static void setboard_gen(sdgen_t *s) {
  if(s->solver==NULL)s->solver=make_sd(s->n,s->table);
  else memcpy(s->solver->table, s->table, sizeof(val_t) * s->ne4);
}

static RESULT solve_gen(sdgen_t *s) {
  setboard_gen(s);
  s->status = solve_sd(s->solver);
  return s->status;
}

static bool try_unset(sdgen_t *s, sz_t idx) {
  val_t t=s->table[idx];
  if(!t)return false;  // already empty
  assert(s->no_vals);
  s->table[idx]=0,solve_gen(s),assert(s->status != INVALID);
  if(s->status == MULTIPLE){s->table[idx]=t;return false;}
  --s->no_vals;
  return true;
}

static void shift_arr(sz_t *arr, sz_t idx, sz_t *len) {
  for(sz_t i=idx; i<*len-1; ++i)arr[i]=arr[i+1];
  --*len;
}

/*
 * Generate a new puzzle.
 *
 * Parameters:
 *   out_table: output buffer for puzzle (size n^4)
 *   n: box size (2 for 4x4, 3 for 9x9, 4 for 16x16)
 *   seed: random seed
 *   difficulty: 0.0 = many hints (easiest), 1.0 = fully reduced (hardest)
 *   timeout_ms: max generation time in milliseconds (0 = no limit)
 *
 * Returns: number of hints in generated puzzle
 */
int32_t generate_puzzle(uint8_t *out_table, int32_t n, uint32_t seed, float difficulty, int32_t timeout_ms) {
  xorshift_state = seed ? seed : (uint32_t)time(NULL);

  sdgen_t s = sdgen_init(n);

  // For small grids (n=2), diagonal box filling may create unsolvable puzzles.
  // Retry with different seeds until we get a solvable configuration.
  int max_retries = 100;
  for(int retry = 0; retry < max_retries; ++retry) {
    memset(s.table, 0, sizeof(val_t) * s.ne4);
    s.no_vals = 0;
    sd_init_diagonal_boxes(&s);
    setboard_gen(&s);
    s.status = solve_sd(s.solver);
    if(s.status != INVALID) break;
    xorshift_state += 1;  // try different seed
  }
  if(s.status == INVALID) {
    // Couldn't find solvable configuration, return empty
    memset(out_table, 0, sizeof(val_t) * s.ne4);
    sdgen_free(&s);
    return 0;
  }
  // Copy solution to table
  for(sz_t i=0;i<s.ne4;++i)s.table[i]=s.solver->table[i];
  s.no_vals=s.ne4;

  sz_t len = s.ne4;
  sz_t *arr = malloc(sizeof(sz_t) * len);
  ord_arr(arr, len);

  // Clamp difficulty to [0, 1]
  if(difficulty < 0.0f)difficulty = 0.0f;
  if(difficulty > 1.0f)difficulty = 1.0f;

  // Log-interpolate between min and max hints
  // difficulty=0 -> max hints (trivial)
  // difficulty=1 -> min hints (hardest)
  // Uses: target = min * (max/min)^(1-difficulty)
  float min_fraction = 0.2f;
  sz_t min_hints = (sz_t)(s.ne4 * min_fraction);
  sz_t max_hints = s.ne4;
  float ratio = (float)max_hints / (float)min_hints;
  sz_t target_hints = (sz_t)(min_hints * powf(ratio, 1.0f - difficulty));
  if(difficulty <= 0.01f)target_hints = s.ne4;  // keep everything

  clock_t start = clock();
  clock_t timeout_clocks = timeout_ms ? (timeout_ms * CLOCKS_PER_SEC / 1000) : 0;

  while(s.no_vals > target_hints) {
    gen_shuffle_arr(arr, len);
    sz_t prev_len = len;

    for(sz_t i = 0; i < len && s.no_vals > target_hints; ++i) {
      if(timeout_clocks && (clock() - start) > timeout_clocks)goto endgen;
      if(try_unset(&s, arr[i]))shift_arr(arr, i--, &len);
    }

    if(prev_len == len)goto endgen;
  }

endgen:;
  // Relabel values randomly
  sz_t *rename = malloc(sizeof(sz_t) * s.ne2);
  ord_arr(rename, s.ne2),gen_shuffle_arr(rename, s.ne2);
  for(sz_t i = 0; i < s.ne4; ++i)if(s.table[i])s.table[i] = rename[s.table[i] - 1] + 1;
  free(rename);

  memcpy(out_table, s.table, sizeof(val_t) * s.ne4);
  int32_t num_hints = (int32_t)s.no_vals;

  free(arr);
  sdgen_free(&s);

  return num_hints;
}

/* ============================================================================
 * FFI EXPORTS
 * ============================================================================ */

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#define EXPORT EMSCRIPTEN_KEEPALIVE
#else
#define EXPORT __attribute__((visibility("default")))
#endif

EXPORT int32_t sd_generate(uint8_t *out_table, int32_t n, uint32_t seed, float difficulty, int32_t timeout_ms) {
  return generate_puzzle(out_table, n, seed, difficulty, timeout_ms);
}

EXPORT int sd_difficulty(const uint8_t *table, int32_t n, int32_t num_samples,
                         int32_t *out_min_fwd, int32_t *out_max_fwd, int32_t *out_avg_fwd,
                         int32_t *out_min_bt, int32_t *out_max_bt, int32_t *out_avg_bt) {
  difficulty_stats_t stats;
  int result = estimate_difficulty(table, n, num_samples, &stats);
  if(result && stats.samples > 0) {
    *out_min_fwd = stats.min_forwards;
    *out_max_fwd = stats.max_forwards;
    *out_avg_fwd = stats.avg_forwards;
    *out_min_bt = stats.min_backtracks;
    *out_max_bt = stats.max_backtracks;
    *out_avg_bt = stats.avg_backtracks;
  }
  return result;
}

EXPORT int sd_solve(uint8_t *table, int32_t n) {
  sd_t *s = make_sd(n, table);
  RESULT res = solve_sd(s);
  if(res == COMPLETE)memcpy(table, s->table, sizeof(val_t) * s->ne4);
  free_sd(s);
  return (int)res;
}
